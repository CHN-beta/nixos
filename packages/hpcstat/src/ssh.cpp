# include <hpcstat/ssh.hpp>
# include <hpcstat/keys.hpp>
# include <hpcstat/env.hpp>
# include <boost/filesystem.hpp>
# include <boost/dll.hpp>

namespace hpcstat::ssh
{
  std::optional<std::string> fingerprint()
  {
    if (auto sshbindir = env::env("HPCSTAT_SSH_BINDIR"); !sshbindir)
      return std::nullopt;
    else if
    (
      auto output = biu::exec
        ({.Program=std::filesystem::path(*sshbindir) / "ssh-add", .Args{ "-l" }, .Timeout=10s});
      !output
    )
      { std::cerr << "Failed to get ssh fingerprints\n"; return std::nullopt; }
    else
    {
      std::regex pattern(R"r(\b(?:sha|SHA)256:([0-9A-Za-z+/=]{43})\b)r");
      std::smatch match;
      for
      (
        auto i = std::sregex_iterator
          (output.Stdout.begin(), output.Stdout.end(), pattern);
        i != std::sregex_iterator();
        ++i
      )
        if (Keys.contains(i->str(1))) return i->str(1);
      std::cerr << "No valid fingerprint found in:\n{}\n"_f(output.Stdout);
      return std::nullopt;
    }
  }
  std::optional<std::string> sign(std::string message, std::string fingerprint)
  {
    if (auto sshbindir = env::env("HPCSTAT_SSH_BINDIR"); !sshbindir)
      return std::nullopt;
    else if (auto sharedir = env::env("HPCSTAT_SHAREDIR", true); !sharedir)
      return std::nullopt;
    else if
    (
      auto output = biu::exec
      ({
        .Program=std::filesystem::path(*sshbindir) / "ssh-keygen",
        .Args={
          "-Y", "sign", "-q", "-f", "{}/keys/{}"_f(*sharedir, Keys[fingerprint].PubkeyFilename),
          "-n", "hpcstat@chn.moe", "-"
        },
        .Stdin=message,
        .Timeout=10s
      });
      !output
    )
      { std::cerr << "Failed to sign message: {}\n"_f(message); return {}; }
    else return output.Stdout;
  }
  bool verify(std::string message, std::string signature, std::string fingerprint)
  {
    if (auto sshbindir = env::env("HPCSTAT_SSH_BINDIR"); !sshbindir)
      return false;
    else if (auto sharedir = env::env("HPCSTAT_SHAREDIR", true); !sharedir)
      return false;
    else
    {
      namespace bf = boost::filesystem;
      auto tempdir = bf::temp_directory_path() / bf::unique_path();
      bf::create_directories(tempdir);
      auto signaturefile = tempdir / "signature";
      std::ofstream(signaturefile) << signature;
      auto result = biu::exec
      ({
        .Program=std::filesystem::path(*sshbindir) / "ssh-keygen",
        .Args={
          "-Y", "verify",
          "-f", "{}/keys/{}"_f(*sharedir, Keys[fingerprint].PubkeyFilename),
          "-n", "hpcstat@chn.moe", "-s", signaturefile.string()
        },
        .Stdin=message,
        .Timeout=10s
      });
      std::filesystem::remove_all(tempdir.string());
      return result;
    }
  }
}

# include <filesystem>
# include <iostream>
# include <regex>
# include <hpcstat/ssh.hpp>
# include <hpcstat/keys.hpp>
# include <hpcstat/env.hpp>
# include <hpcstat/common.hpp>
# include <fmt/format.h>
# include <boost/filesystem.hpp>
# include <boost/process.hpp>
# include <boost/dll.hpp>

namespace hpcstat::ssh
{
  std::optional<std::string> fingerprint()
  {
    if (auto sshbindir = env::env("HPCSTAT_SSH_BINDIR"); !sshbindir)
      return std::nullopt;
    else if
    (
      auto output =
        exec(std::filesystem::path(*sshbindir) / "ssh-add", { "-l" });
      !output
    )
      { std::cerr << "Failed to get ssh fingerprints\n"; return std::nullopt; }
    else
    {
      std::regex pattern(R"r(\b(?:sha|SHA)256:([0-9A-Za-z+/=]{43})\b)r");
      std::smatch match;
      for
      (
        auto i = std::sregex_iterator(output->begin(), output->end(), pattern);
        i != std::sregex_iterator(); ++i
      )
        if (Keys.contains(i->str(1))) return i->str(1);
      std::cerr << fmt::format("No valid fingerprint found in:\n{}\n", *output);
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
      auto output = exec
      (
        std::filesystem::path(*sshbindir) / "ssh-keygen",
        {
          "-Y", "sign", "-q",
          "-f", fmt::format("{}/keys/{}", *sharedir, Keys[fingerprint].PubkeyFilename),
          "-n", "hpcstat@chn.moe", "-"
        },
        message
      );
      !output
    )
      { std::cerr << fmt::format("Failed to sign message: {}\n", message); return std::nullopt; }
    else return *output;
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
      return exec
      (
        std::filesystem::path(*sshbindir) / "ssh-keygen",
        {
          "-Y", "verify",
          "-f", fmt::format("{}/keys/{}", *sharedir, Keys[fingerprint].PubkeyFilename),
          "-n", "hpcstat@chn.moe", "-s", signaturefile.string()
        },
        message
      ).has_value();
    }
  }
}

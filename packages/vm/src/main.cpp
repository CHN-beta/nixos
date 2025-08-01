# include <biu.hpp>

# ifndef VM_CONFIG
#   define VM_CONFIG "./vm.yaml"
# endif

int main(int argc, char** argv)
{
  using namespace biu::literals;
  biu::Logger::try_exec([&]
  {
    struct
    {
      std::string virsh;
      std::map<uid_t, std::set<std::string>> vm;
    } config = YAML::LoadFile(VM_CONFIG).as<decltype(config)>();
    auto uid = getuid();
    if (setuid(0) == -1) throw std::runtime_error("Failed to setuid to root");
    if (setgid(0) == -1) throw std::runtime_error("Failed to setgid to root");
    std::vector<std::string> args(argv + 1, argv + argc);
    std::map<std::string, std::string> vm_to_virsh =
    {
      {"status", "dominfo"},
      {"start", "start"},
      {"stop", "shutdown"},
      {"force-stop", "destroy"},
      {"reboot", "reboot"},
      {"force-reboot", "reset"}
    };
    if (args.empty()) std::cout << R"(
vm list
  get list of VMs owned by current user
vm status <vm>
  get status of specified VM (virsh dominfo)
vm start <vm>
  start specified VM if it is not running (virsh start)
vm stop <vm>
  try to gracefully stop specified VM (may not success, virsh shutdown)
vm force-stop <vm>
  force stop specified VM (virsh destroy)
vm reboot <vm>
  reboot specified VM (virsh reboot)
vm force-reboot <vm>
  force reboot specified VM (virsh reset)
)";
    else if (args[0] == "list")
    {
      if (!config.vm.contains(uid)) throw std::runtime_error("No VM found for current user");
      std::cout << "{}\n"_f(config.vm[uid]);
    }
    else if (vm_to_virsh.contains(args[0]))
    {
      if (args.size() != 2)
        throw std::runtime_error("Invalid argument count, expected 2, received {}"_f(args.size()));
      if (!config.vm.contains(uid)) throw std::runtime_error("No VM found for current user");
      if (!config.vm[uid].contains(args[1]))
        throw std::runtime_error("VM {} is not owned by current user"_f(args[1]));
      biu::exec({config.virsh, { vm_to_virsh[args[0]], args[1] }});
    }
    else throw std::runtime_error("unknown command: {}"_f(args[0]));
  });
}

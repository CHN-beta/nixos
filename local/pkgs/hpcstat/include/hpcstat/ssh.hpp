# pragma once
# include <optional>
# include <string>

namespace hpcstat::ssh
{
  // get a valid public key fingerprint
  std::optional<std::string> fingerprint();
  // sign a message with the key of specified fingerprint
  std::optional<std::string> sign(std::string message, std::string fingerprint);
  // verify a message with the key of specified fingerprint
  bool verify(std::string message, std::string signature, std::string fingerprint);
}

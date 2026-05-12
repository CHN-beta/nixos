# pragma once
# include <pocketfft.h>

namespace biu::fft
{
  template <typename T> std::vector<std::complex<T>> forward(std::vector<T> input);
  template <typename T> std::vector<T> backward
    (std::vector<std::complex<T>> input, std::optional<std::size_t> output_size = std::nullopt);
}

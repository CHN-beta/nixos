# pragma once
# include <biu/fft.hpp>

namespace biu::fft
{
  template <typename T> std::vector<std::complex<T>> forward(std::vector<T> input)
  {
    std::vector<std::complex<T>> output(input.size() / 2 + 1);
    pocketfft::r2c<T>
    (
      {input.size()}, {sizeof(T)}, {sizeof(std::complex<T>)},
      0, pocketfft::FORWARD, input.data(), output.data(), 1
    );
    return output;
  }
  template <typename T> std::vector<T> backward
    (std::vector<std::complex<T>> input, std::optional<std::size_t> output_size)
  {
    if (!output_size) output_size = (input.size() - 1) * 2;
    else [[unlikely]] assert(*output_size / 2 + 1 == input.size());
    std::vector<T> output(*output_size);
    pocketfft::c2r<T>
    (
      {output.size()}, {sizeof(std::complex<T>)}, {sizeof(T)},
      0, pocketfft::BACKWARD, input.data(), output.data(), 1
    );
    return output;
  }
}

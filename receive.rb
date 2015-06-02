require "coreaudio"
require "fftw3"
require "./constants"

Thread.abort_on_exception = true

PEAK_INDICES = FREQUENCIES.map do |f|
  i = (f.to_f / RATE * CHUNK_SIZE).round
  [i - 1, i, i + 1]
end

buf = CoreAudio.default_input_device.input_buffer(BUFFER_SIZE)
FRACTIONAL_BIT_STREAM = Queue.new

def process_chunk(chunk)
  fft = FFTW3.fft(chunk).real.abs
  arr = fft.to_a

  max = arr.max
  thresh = max * 0.90

  # find indices in the FFT above the threshold value
  ind = []
  arr.each_with_index do |x, i|
    ind << i if x > thresh
  end

  # correlate find indices found in the FFT to bits
  bits = []
  PEAK_INDICES.each_with_index do |peak_indices, bit|
    bits << bit if (ind & peak_indices).any?
  end

  FRACTIONAL_BIT_STREAM.push(bits.inspect)
end

listen_thread = Thread.start do
  loop do
    waveform = buf.read(BUFFER_SIZE)
    channel = waveform[0, true]
    (0...(BUFFER_SIZE/CHUNK_SIZE)).each do |i|
      chunk = channel[i...(i+CHUNK_SIZE)]
      process_chunk(chunk)
    end
  end
end

process_thread = Thread.start do
  while bits = FRACTIONAL_BIT_STREAM.pop
    puts bits
  end
end

buf.start
sleep 5
buf.stop

listen_thread.kill.join
process_thread.kill.join

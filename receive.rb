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

def highest_signal(occurrences)
  return 0 unless occurrences.any?
  occurrences.max_by {|_, v| v}.first
end

def confidence(window, bit)
  window.reduce(0) {|acc, bits| acc + (bits.include?(bit) ? 1/bits.size : -bits.size) }.to_f / window.size
end

def bits_to_char(bit_array)
  byte = bit_array.reduce(0) {|acc, bit| (acc << 1) + bit}
  [byte].pack("c")
end

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

  FRACTIONAL_BIT_STREAM.push(bits)
end

listen_thread = Thread.start do
  loop do
    waveform = buf.read(BUFFER_SIZE)
    channel = waveform[0, true]
    (0...CHUNKS_PER_BUFFER).each do |i|
      chunk = channel[i...(i+CHUNK_SIZE)]
      process_chunk(chunk)
    end
  end
end

process_thread = Thread.start do
  # calibrate
  window = Array.new(CHUNKS_PER_BUFFER, 0)
  while bits = FRACTIONAL_BIT_STREAM.pop
    window = window[1..-1]
    window << (bits == [1] ? 1 : 0)
    break if window.inject(&:+) == CHUNKS_PER_BUFFER
  end

  # we're calibrated
  puts "calibrated"
  window = []
  occurrences = Hash.new(0)
  while bits = FRACTIONAL_BIT_STREAM.pop
    window << bits
    bits.each {|bit| occurrences[bit] += 1}
    if window.size >= CHUNKS_PER_BUFFER
      bit = highest_signal(occurrences)
      printf "%1d (%2.2f)\n", bit, confidence(window, bit)
      window = []
      occurrences = Hash.new(0)
    end
  end
end

buf.start
sleep 5
buf.stop

listen_thread.kill.join
process_thread.kill.join

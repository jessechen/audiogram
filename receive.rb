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
  max = 0
  index = 0
  occurrences.each do |k, v|
    if v > max
      max = v
      index = k
    end
  end
  index
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
    (0...(BUFFER_SIZE/CHUNK_SIZE)).each do |i|
      chunk = channel[i...(i+CHUNK_SIZE)]
      process_chunk(chunk)
    end
  end
end

process_thread = Thread.start do
  # calibrate
  window = [0, 0, 0, 0]
  while bits = FRACTIONAL_BIT_STREAM.pop
    window = window[1..-1]
    window << (bits == [1] ? 0.25 : 0)
    break if window.inject(&:+) == 1
  end

  # we're calibrated
  puts "calibrated"
  counter = 0
  occurrences = Hash.new(0)
  while bits = FRACTIONAL_BIT_STREAM.pop
    counter += 1
    bits.each {|bit| occurrences[bit] += 1}
    if counter >= 4
      puts highest_signal(occurrences)
      counter = 0
      occurrences = Hash.new(0)
    end
  end

end

buf.start
sleep 5
buf.stop

listen_thread.kill.join
process_thread.kill.join

require "coreaudio"
require "fftw3"
require "./constants"

PEAK_INDICES = FREQUENCIES.map do |f|
  i = (f.to_f / RATE * CHUNK_SIZE).round
  [i - 1, i, i + 1]
end

buf = CoreAudio.default_input_device.input_buffer(BUFFER_SIZE)

def process(chunk)
  fft = FFTW3.fft(chunk).real.abs
  arr = fft.to_a

  max = arr.max
  thresh = max * 0.90

  ind = []
  arr.each_with_index do |x, i|
    ind << i if x > thresh
  end

  bits = []
  PEAK_INDICES.each_with_index do |peak_indices, bit|
    bits << bit if (ind & peak_indices).any?
  end

  puts bits.inspect
end

listen_thread = Thread.start do
  read = 0
  loop do
    waveform = buf.read(BUFFER_SIZE)
    channel = waveform[0, true]

    (0...(BUFFER_SIZE/CHUNK_SIZE)).each do |i|
      chunk = channel[i...(i+CHUNK_SIZE)]
      process(chunk)
    end

    read += BUFFER_SIZE
    puts "read: #{read.inspect} samples"
  end
end

buf.start
sleep DURATION + WARMUP
buf.stop

listen_thread.kill.join

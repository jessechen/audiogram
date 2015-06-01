require "coreaudio"
require "fftw3"

DEV         = CoreAudio.default_input_device
FREQUENCY   = 19100
RATE        = DEV.nominal_rate # 44100
BUFFER_SIZE = 1024
CHUNK_SIZE  = 256

buf = DEV.input_buffer(BUFFER_SIZE)

def process(chunk)
  fft = FFTW3.fft(chunk).real.abs
  arr = fft.to_a
  max = arr.max.round
  sum = arr.inject(&:+).round
  avg = sum / arr.size
  printf "avg: %10d, max: %10d\n", avg, max
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
sleep 1
buf.stop

listen_thread.kill.join

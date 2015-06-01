require "coreaudio"
require "fftw3"

dev = CoreAudio.default_input_device
frequency     = 19100
rate          = dev.nominal_rate # 44100
chunk_size    = 1024
fragment_size = 256

buf = dev.input_buffer(chunk_size)

def process(fragment)
  fft = FFTW3.fft(fragment).real.abs
  arr = fft.to_a
  max = arr.max.round
  sum = arr.inject(&:+).round
  avg = sum / arr.size
  printf "avg: %10d, max: %10d\n", avg, max
end

listen_thread = Thread.start do
  read = 0
  loop do
    waveform = buf.read(chunk_size)
    channel = waveform[0, true]

    (0...(chunk_size/fragment_size)).each do |i|
      fragment = channel[i...(i+fragment_size)]
      process(fragment)
    end

    read += chunk_size
    puts "read: #{read.inspect}"
  end
end

buf.start
sleep 1
buf.stop

listen_thread.kill.join

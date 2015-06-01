require "coreaudio"
require "fftw3"

CHUNK_SIZE=256

dev = CoreAudio.default_input_device
buf = dev.input_buffer(CHUNK_SIZE)

thread = Thread.start do
  loop do
    waveform = buf.read(CHUNK_SIZE)
    channel = waveform[0, true]
    f = FFTW3.fft(channel).real.abs
    arr = f.to_a
    arr.map(&:round).each_slice(16) do |s|
      printf (" %6d" * 16)+"\n", *s
    end
    max = arr.max.round
    sum = arr.inject(&:+).round
    avg = sum / arr.size
    printf "avg: %10d, max: %10d\n", avg, max
  end
end

buf.start
sleep 1
buf.stop

thread.kill.join

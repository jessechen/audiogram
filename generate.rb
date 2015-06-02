require "coreaudio"
require "./constants"

VOLUME = 0.4

buf = CoreAudio.default_output_device.output_buffer(BUFFER_SIZE)

thread = Thread.start do
  sleep WARMUP

  data = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1 ,1]
  freqs = data.map {|i| FREQUENCIES[i] }

  i = 0
  wav = NArray.sint(BUFFER_SIZE)
  freqs.each do |f|
    phase = Math::PI * 2.0 * f / RATE
    BUFFER_SIZE.times {|j| wav[j] = (VOLUME * Math.sin(phase * (i+j)) * 0x7FFF).round }
    i += BUFFER_SIZE
    buf << wav
  end
  puts "wrote: #{i.inspect} samples"
end

buf.start
sleep DURATION + WARMUP
buf.stop

thread.kill.join

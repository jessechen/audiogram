require "coreaudio"

dev = CoreAudio.default_output_device
buf = dev.output_buffer(1024)

frequency = 19100.0
phase = Math::PI * 2.0 * frequency / dev.nominal_rate
thread = Thread.start do
  data = [1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1 ,1]
  i = 0
  wav = NArray.sint(1024)
  data.each do |bit|
    1024.times {|j| wav[j] = (0.4 * Math.sin(phase*bit*(i+j)) * 0x7FFF).round }
    i += 1024
    buf << wav
  end
end

buf.start
sleep 1
buf.stop

thread.kill.join

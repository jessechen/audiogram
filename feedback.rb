require "coreaudio"

in_dev = CoreAudio.default_input_device
out_dev = CoreAudio.default_output_device
in_buf = in_dev.input_buffer(1024)
out_buf = out_dev.output_buffer(1024)

frequency = 440.0
phase = Math::PI * 2.0 * frequency / out_dev.nominal_rate
output_thread = Thread.start do
  i = 0
  wav = NArray.sint(1024)
  loop do
    1024.times {|j| wav[j] = (0.4 * Math.sin(phase*(i+j)) * 0x7FFF).round }
    i += 1024
    out_buf << wav
  end
end

input_thread = Thread.start do
  loop do
    waveform = in_buf.read(1024)
    puts waveform[0, true].inspect
  end
end

in_buf.start
out_buf.start
sleep 2
in_buf.stop
out_buf.stop

output_thread.kill.join
input_thread.kill.join

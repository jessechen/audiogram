require "coreaudio"

dev = CoreAudio.default_input_device
buf = dev.input_buffer(1024)

thread = Thread.start do
  loop do
    waveform = buf.read(1024)
    puts waveform[0, true].inspect
  end
end

buf.start
sleep 10
buf.stop

thread.kill.join

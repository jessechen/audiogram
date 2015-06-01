require "coreaudio"

dev = CoreAudio.default_input_device
buf = dev.input_buffer(1024)

thread = Thread.start do
  loop do
    waveform = buf.read(1024)
    channel = waveform[0, true].to_a
    channel.each_slice(16) do |chunk|
      puts chunk.inspect
    end
  end
end

buf.start
sleep 0.5
buf.stop

thread.kill.join

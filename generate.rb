require "coreaudio"

dev = CoreAudio.default_output_device
frequency  = 19100
rate       = dev.nominal_rate # 44100
chunk_size = 1024
phase      = Math::PI * 2.0 * frequency / rate

buf = dev.output_buffer(chunk_size)

thread = Thread.start do
  data = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1 ,1]
  i = 0
  wav = NArray.sint(chunk_size)
  data.each do |bit|
    chunk_size.times {|j| wav[j] = (0.4 * Math.sin(phase*bit*(i+j)) * 0x7FFF).round }
    i += chunk_size
    buf << wav
  end
  puts "wrote: #{i.inspect}"
end

buf.start
sleep 1
buf.stop

thread.kill.join

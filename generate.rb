require "coreaudio"
require "./constants"

buf = CoreAudio.default_output_device.output_buffer(BUFFER_SIZE)

thread = Thread.start do
  data = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1 ,1]
  i = 0
  wav = NArray.sint(BUFFER_SIZE)
  data.each do |bit|
    BUFFER_SIZE.times {|j| wav[j] = (0.4 * Math.sin(PHASE*bit*(i+j)) * 0x7FFF).round }
    i += BUFFER_SIZE
    buf << wav
  end
  puts "wrote: #{i.inspect} samples"
end

buf.start
sleep 1
buf.stop

thread.kill.join

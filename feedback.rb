require "coreaudio"

dev = CoreAudio.default_output_device

queue = Queue.new
frequency = 440.0
phase = Math::PI * 2.0 * frequency / dev.nominal_rate
output_thread = Thread.start do
  i = 0
  wav = NArray.sint(1024)
  loop do
    1024.times {|j| wav[j] = (0.4 * Math.sin(phase*(i+j)) * 0x7FFF).round }
    i += 1024
    queue << wav
  end
end

input_thread = Thread.start do
  while w = queue.pop
    puts w.inspect
  end
end

sleep 2

output_thread.kill.join
input_thread.kill.join

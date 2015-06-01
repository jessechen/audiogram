require "coreaudio"

def send_calibration(buf)
  frequency = 220.0
  phase = Math::PI * 2.0 * frequency / 44100

  i = 0
  wav = NArray.sint(1024)
  loop do
    1024.times do |j|
      polarity = Math.sin(phase*(i+j))
      wav[j] = polarity < 0 ? -0x7FFF : 0x7FFF
    end
    i += 1024
    puts wav.inspect
    buf << wav
  end
end

dev = CoreAudio.default_output_device
buf = dev.output_buffer(1024)

frequency = 440.0
phase = Math::PI * 2.0 * frequency / dev.nominal_rate
thread = Thread.start do
  puts "here"
  send_calibration(buf)

  i = 0
  wav = NArray.sint(1024)
  loop do
    1024.times {|j| wav[j] = (0.4 * Math.sin(phase*(i+j)) * 0x7FFF).round }
    i += 1024
    # buf << wav
  end
end

buf.start
sleep 2
buf.stop

thread.kill.join

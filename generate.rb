require "coreaudio"
require "./constants"

Thread.abort_on_exception = true

VOLUME = 0.4

buf = CoreAudio.default_output_device.output_buffer(BUFFER_SIZE)

calibration = [0, 1] * 8 + [0] * 4
data = calibration + [0, 1, 0, 0, 1, 0, 0, 0]
freqs = data.map {|i| FREQUENCIES[i] }
duration = data.length.to_f * BUFFER_SIZE / RATE

thread = Thread.start do
  sleep WARMUP

  i = 0
  wav = NArray.sint(BUFFER_SIZE)
  freqs.each do |f|
    phase = Math::PI * 2.0 * f / RATE
    BUFFER_SIZE.times {|j| wav[j] = (VOLUME * Math.sin(phase * (i+j)) * 0x7FFF).round }
    i += BUFFER_SIZE
    buf << wav
  end
end

buf.start
sleep duration + WARMUP * 2
buf.stop

thread.kill.join

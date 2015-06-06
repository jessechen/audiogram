require "coreaudio"
require "./constants"

Thread.abort_on_exception = true

available_rates = CoreAudio.default_output_device.available_sample_rate.flatten.uniq
rate = RATE.to_f
if (!rate || !available_rates.member?(rate))
  puts "Please enter a valid sample rate. Choose one of the following: #{available_rates.join(', ')}"
  return -1
end

CoreAudio.default_output_device(nominal_rate: rate)
puts "Output device sample rate set to #{rate}"

BUF = CoreAudio.default_output_device.output_buffer(BUFFER_SIZE)

# calibration = [0] * 6 + [1, 0] * CALIBRATION_SIGNALS + [0] * (ZEROES_AFTER_CALIBRATION-1)
# data = calibration + [1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1]

data = [1, 0] * 60

freqs = data.map {|i| FREQUENCIES[i] }
duration = data.length.to_f * BUFFER_SIZE / RATE

thread = Thread.start do
  sleep WARMUP

  i = 0
  wav = NArray.sint(BUFFER_SIZE)
  freqs.each_with_index do |f, freqs_index|
    damp_l = (f != ((freqs_index-1) < 0 ? FREQUENCIES[0] : freqs[freqs_index-1]))
    damp_r = (f != ((freqs_index+1) >= freqs.size ? FREQUENCIES[0] : freqs[freqs_index+1]))
    phase = Math::PI * 2.0 * f / RATE

    half = BUFFER_SIZE / 2.0
    damp_freq = Math::PI / half

    BUFFER_SIZE.times do |j|
      signal = (VOLUME * Math.sin(phase * (i+j)) * 0x7FFF).round
      if (damp_l and j < half) or (damp_r and j >= half)
        adj = (1 + Math.sin(damp_freq * (i+j) - Math::PI/2)) / 2.0
        # puts "damping: #{adj}"
        signal *= adj
      end
      wav[j] = signal
    end

    i += BUFFER_SIZE
    BUF << wav
  end
end

BUF.start
sleep duration + WARMUP * 2
BUF.stop

thread.kill.join

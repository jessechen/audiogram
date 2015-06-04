require "coreaudio"
require "./constants"
require "./telegraph"

Thread.abort_on_exception = true

VOLUME = 0.4

BUF = CoreAudio.default_output_device.output_buffer(BUFFER_SIZE)

calibration = [0] * 6 + [1, 0] * CALIBRATION_SIGNALS + [0] * (ZEROES_AFTER_CALIBRATION-1)
bits = signals_to_bits(encode("anything"))
data = calibration + bits

freqs = data.map {|i| FREQUENCIES[i] }

send_thread = Thread.start do
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

input_thread = Thread.start do
  while (text_to_send = gets)
    words = text_to_send.strip.split(/\s+/)
    bits = words.map {|word| signals_to_bits(encode(word)) + END_OF_WORD}.flatten
    puts bits.inspect
  end
end

# Stop listening on ^C
Signal.trap('INT') do
  BUF.stop
  send_thread.kill
  input_thread.kill
end

BUF.start

# send_thread.join
input_thread.join

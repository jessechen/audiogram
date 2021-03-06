require "coreaudio"
require "./constants"
require "./telegraph"

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

calibration_bits = [0] * 6 + [1, 0] * CALIBRATION_SIGNALS + [0] * (ZEROES_AFTER_CALIBRATION-1)
DATA_QUEUE = Queue.new
calibration_bits.each { |bit| DATA_QUEUE << bit }

send_thread = Thread.start do
  sleep WARMUP

  i = 0
  wav = NArray.sint(BUFFER_SIZE)
  prev_freq = FREQUENCIES[0]
  curr_freq = FREQUENCIES[0]
  next_freq = FREQUENCIES[0]

  while true
    value = begin
      DATA_QUEUE.deq(true)
    rescue ThreadError
      0
    end
    prev_freq = curr_freq
    curr_freq = next_freq
    next_freq = FREQUENCIES[value]

    damp_l = (curr_freq != prev_freq)
    damp_r = (curr_freq != next_freq)
    phase = Math::PI * 2.0 * curr_freq / RATE

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
    bits.each { |bit| DATA_QUEUE << bit }
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

require "coreaudio"
require "fftw3"
require "./constants"
require "./telegraph"

Thread.abort_on_exception = true

available_rates = CoreAudio.default_input_device.available_sample_rate.flatten.uniq
rate = RATE.to_f
if (!rate || !available_rates.member?(rate))
  puts "Please enter a valid sample rate. Choose one of the following: #{available_rates.join(', ')}"
  return -1
end

CoreAudio.default_input_device(nominal_rate: rate)
puts "Input device sample rate set to #{rate}"

BUF = CoreAudio.default_input_device.input_buffer(BUFFER_SIZE)

CHUNK_STREAM = Queue.new
BIT_STREAM = Queue.new

def bits_to_char(bit_array)
  byte = bit_array.reduce(0) {|acc, bit| (acc << 1) + bit}
  [byte].pack("c")
end

def mean(arr)
  return 0 if arr.size == 0
  arr.inject(&:+) / arr.size.to_f
end

def harmonic_mean(arr)
  return 0 if arr.size == 0
  1.0 / (arr.map {|x| 1.0 / x }.inject(&:+) / arr.size.to_f)
end

def process_signal(signal)
  fft = FFTW3.fft(signal).abs
  indices = peak_indices(FREQUENCIES[1], signal.size)
  area_under_peaks = indices.map {|i| fft[i] }.inject(&:+)

  # print_to_graph(signal, fft, area_under_peaks) if signal.size == BUFFER_SIZE
  area_under_peaks
end

# peak_indices for f=1760, s=512:  [19, 20, 21]
# peak_indices for f=1760, s=4608: [183, 184, 185]
def peak_indices(target_frequency, sample_size)
  i = (target_frequency.to_f / RATE * sample_size).round
  (i-SUM_DISTANCE_FROM_PEAK..i+SUM_DISTANCE_FROM_PEAK).to_a
end

def print_to_graph(signal, fft, aup)
  $iter = ($iter || 0) + 1
  signal = signal.to_a
  fft = fft.to_a
  sum = fft.inject(&:+)
  avg = sum / fft.size
  max = fft.max
  File.open("js/data#{$iter}.json", "w") do |f|
    text = "sum: #{sum.round}, avg: #{avg.round}, max: #{max.round}, aup: #{aup.round}"
    f << "{\"fft\":" + fft.inspect + ", \"signal\":" + signal.inspect + ", \"text\": \"" + text + "\" }"
  end
end

def buf_reader(record_to_file)
  f = File.open(record_to_file, "w") if record_to_file
  loop do
    waveform = BUF.read(BUFFER_SIZE)
    channel = waveform[0, true]
    f << channel.to_a.inspect if record_to_file
    f << "\n" if record_to_file
    yield channel
  end
end

def file_reader(read_from_file)
  File.open(read_from_file, "r") do |f|
    f.each_line do |line|
      if line.size > 0
        data = NArray.to_na(eval(line))
        yield data
      end
    end
  end
end

listen_thread = Thread.start do
  p = lambda do |data|
    (0...CHUNKS_PER_BUFFER).each do |i|
      start = i*CHUNK_SIZE
      chunk = data[start...(start+CHUNK_SIZE)]
      CHUNK_STREAM << chunk
    end
  end

  if ARGV[0] == "read"
    file_reader(ARGV[1], &p)
  elsif ARGV[0] == "record"
    buf_reader(ARGV[1], &p)
  else
    buf_reader(nil, &p)
  end
end

signal_processing_thread = Thread.start do
  # calibrate
  puts "Waiting for calibration signal..."
  window = Array.new

  # load initial window
  while window.size < CHUNKS_PER_BUFFER
    window << process_signal(CHUNK_STREAM.pop)
  end

  # start trying to find value
  means = []
  calibrating = false
  calibration_indexes = []
  while (m = process_signal(CHUNK_STREAM.pop))
    # rotate chunks into window, calculating moving mean
    window = window[1..-1]
    window << m
    wmean = mean(window)
    # puts "measurement: #{m.round} window: #{window.map(&:round)}, mean: #{mean(window).round}, hmean: #{harmonic_mean(window).round}"
    means << wmean

    puts "calibrate? #{wmean.round}" if !calibrating and ENV['CALIBRATE'] == "true"
    if !calibrating and wmean > CALIBRATION_THRESHOLD
      puts "Found calibration signal. Calibrating..."
      calibrating = true
    end

    # once we have a full 2*window of means, process them
    if means.size == CHUNKS_PER_BUFFER*2
      # since we've seen a set of means above the calibration threshold, start figuring out the midpoint index
      if calibrating
        # puts "chunk of means: #{means.map(&:round)}"
        # find indexes of min and max of means array
        min = 100000000
        max = 0
        min_index = max_index = mid_index = -1
        means.each_with_index do |v, i|
          if v < min
            min = v
            min_index = i
          end
          if v > max
            max = v
            max_index = i
          end
        end

        # calculate mid-point between min and max indexes
        if min_index <= max_index
          mid_index = ((max_index - min_index) / 2).floor + min_index
        else
          mid_index = (((max_index + CHUNKS_PER_BUFFER*2) - min_index) / 2).floor + min_index
        end
        mid_index = (mid_index - (CHUNKS_PER_BUFFER/2).floor + 1) % (CHUNKS_PER_BUFFER*2) # step back a few indices to account for SMA, and normalize to calibration buffer length
        calibration_indexes << mid_index

        # puts "min: #{min.round}, minI: #{min_index}, max: #{max.round}, maxI: #{max_index}, max/min: #{(max/min).round}, midI: #{mid_index}"

        # wait until we have enough calibration indexes
        if calibration_indexes.size > (CALIBRATION_SIGNALS * 0.75)
          # average the middle to get the target index
          best_calibration_indexes = calibration_indexes.sort[2..-3]
          # puts "best_calibration_indexes: #{best_calibration_indexes}"
          calibration_index = (best_calibration_indexes.inject(&:+) / best_calibration_indexes.size).round

          puts "Dropping #{calibration_index} chunks to align window..."
          calibration_index.times { CHUNK_STREAM.pop }

          break
        end
      end

      means = []
    end
  end
  puts "Calibration complete."

  # we're calibrated
  real_data = false
  num_zeroes = 0
  min_seen = 10000000000
  max_seen = 0
  window = []
  while (c = CHUNK_STREAM.pop)
    window << c
    if window.size == CHUNKS_PER_BUFFER
      combined = NArray.to_na(window.map(&:to_a).inject(&:+))
      measurement = process_signal(combined)

      bit = measurement > BIT_THRESHOLD ? 1 : 0
      if bit == 1
        min_seen = measurement if measurement < min_seen
      else
        max_seen = measurement if measurement > max_seen
      end
      puts "bit: #{bit}, #{measurement.round} (min: #{min_seen.round}, max: #{max_seen.round})" if ENV['CALIBRATE'] == "true"

      if !real_data
        num_zeroes = bit == 1 ? 0 : num_zeroes + 1
        if num_zeroes >= ZEROES_AFTER_CALIBRATION
          real_data = true
          puts "Calibration pattern done, real data starting!"
          puts ""
        end
      else
        BIT_STREAM.push(bit)
      end

      window = []
    end
  end
end

morse_processing_thread = Thread.start do
  current_word = ''
  while (bit = BIT_STREAM.pop)
    current_word << bit.to_s
    if current_word.match(/0{6,}/) # 6 or more consecutive zeros
      signals = bits_to_signals(current_word.gsub(/0{6,}/, ''))
      print(signals.map {|s| decode s}.join('') + ' ')
      current_word = ''
    end
  end
end

# Stop listening on ^C
Signal.trap('INT') do
  BUF.stop
  listen_thread.kill
  signal_processing_thread.kill
  morse_processing_thread.kill
end

BUF.start

listen_thread.join
signal_processing_thread.join
morse_processing_thread.join

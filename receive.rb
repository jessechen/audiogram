require "coreaudio"
require "fftw3"
require "./constants"

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

def variance(arr)
  m = mean(arr)
  sum = arr.inject(0) {|acc, x| acc + (x-m)**2 }
  sum/(arr.size - 1).to_f
end

def standard_deviation(arr)
  Math.sqrt(variance(arr))
end

def standard_deviation_ratio(arr)
  standard_deviation(arr) / mean(arr)
end

def process_signal(signal)
  fft = FFTW3.fft(signal).real.abs
  arr = fft.to_a
  indices = peak_indices(FREQUENCIES[1], signal.size)
  area_under_peaks = indices.map {|i| arr[i] }.inject(&:+)

  # print_to_graph(signal, fft, area_under_peaks)
  area_under_peaks
end

# peak_indices for f=1760, s=512:  [19, 20, 21, 493, 492, 491]
# peak_indices for f=1760, s=4608: [183, 184, 185, 4425, 4424, 4423]
def peak_indices(target_frequency, sample_size)
  i = (target_frequency.to_f / RATE * sample_size).round
  arr = (i-SUM_DISTANCE_FROM_PEAK..i+SUM_DISTANCE_FROM_PEAK).to_a
  arr + arr.map {|x| sample_size - x }
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

def buf_reader(record_to_file = false)
  f = File.open("sample.wav", "w") if record_to_file
  loop do
    waveform = BUF.read(BUFFER_SIZE)
    channel = waveform[0, true]
    f << channel.to_a.inspect if record_to_file
    f << "\n" if record_to_file
    yield channel
  end
end

def file_reader
  File.open("sample.wav", "r") do |f|
    f.each_line do |line|
      if line.size > 0
        data = NArray.to_na(eval(line))
        yield data
      end
    end
  end
end

listen_thread = Thread.start do
  buf_reader(true) do |data|
  # file_reader do |data|
    (0...CHUNKS_PER_BUFFER).each do |i|
      start = i*CHUNK_SIZE
      chunk = data[start...(start+CHUNK_SIZE)]
      CHUNK_STREAM << chunk
    end
  end
end

process_thread = Thread.start do
  # calibrate
  puts "Waiting for calibration signal..."
  window = Array.new()

  # load initial window
  while window.size < CHUNKS_PER_BUFFER
    window << process_signal(CHUNK_STREAM.pop)
  end

  # start trying to find value
  means = []
  calibrating = false
  calibration_indexes = []
  while m = process_signal(CHUNK_STREAM.pop)
    # rotate chunks into window, calculating moving mean
    window = window[1..-1]
    window << m
    # puts "measurement: #{m.round} window: #{window.map(&:round)}, mean: #{mean(window).round}, hmean: #{harmonic_mean(window).round}"
    means << harmonic_mean(window)

    # once we have a full 2*window of means, process them
    if means.size == CHUNKS_PER_BUFFER*2
      if !calibrating and harmonic_mean(means) > CALIBRATION_THRESHOLD
        puts "Found calibrating signal. Calibrating..."
        calibrating = true
      end

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
        mid_index = (mid_index - (CHUNKS_PER_BUFFER/2).floor) % (CHUNKS_PER_BUFFER*2) # step back a few indices to account for SMA, and normalize to calibration buffer length
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

  methods = {
    "mean"      => lambda {|w| mean(w.map {|c| process_signal(c) }).round },
    "mean-2"    => lambda {|w| mean(w[1..-2].map {|c| process_signal(c) }).round },
    "mean-4"    => lambda {|w| mean(w[2..-3].map {|c| process_signal(c) }).round },
    "hmean"     => lambda {|w| harmonic_mean(w.map {|c| process_signal(c) }).round },
    "hmean-2"   => lambda {|w| harmonic_mean(w[1..-2].map {|c| process_signal(c) }).round },
    "hmean-4"   => lambda {|w| harmonic_mean(w[2..-3].map {|c| process_signal(c) }).round },
    "combine"   => lambda {|w| process_signal(NArray.to_na(w.map(&:to_a).inject(&:+))).round },
    "combine-2" => lambda {|w| process_signal(NArray.to_na(w[1..-2].map(&:to_a).inject(&:+))).round },
    "combine-4" => lambda {|w| process_signal(NArray.to_na(w[2..-3].map(&:to_a).inject(&:+))).round },
    "mchunk-3"  => lambda {|w| mean(w.each_slice(3).map {|s| process_signal(NArray.to_na(w.map(&:to_a).inject(&:+))).round }) },
    "hchunk-3"  => lambda {|w| harmonic_mean(w.each_slice(3).map {|s| process_signal(NArray.to_na(w.map(&:to_a).inject(&:+))).round }.to_a) },
    "amp"       => lambda {|w| w.map(&:to_a).flatten.map(&:abs).inject(&:+).round },
    "amp-2"     => lambda {|w| w[1..-2].map(&:to_a).flatten.map(&:abs).inject(&:+).round },
    "amp-4"     => lambda {|w| w[2..-3].map(&:to_a).flatten.map(&:abs).inject(&:+).round },
    "fftarea"   => lambda {|w| FFTW3.fft(NArray.to_na(w.map(&:to_a).inject(&:+))).real.abs.to_a.inject(&:+).round },
    "fftarea-2" => lambda {|w| FFTW3.fft(NArray.to_na(w[1..-2].map(&:to_a).inject(&:+))).real.abs.to_a.inject(&:+).round },
    "fftarea-4" => lambda {|w| FFTW3.fft(NArray.to_na(w[2..-3].map(&:to_a).inject(&:+))).real.abs.to_a.inject(&:+).round },
  }
  method_names = methods.map {|name, fn| name }
  method_results = { highs: {}, lows: {}, ratios: {} }

  # we're calibrated
  real_data = false
  num_zeroes = 0
  window = []
  windows = []
  while c = CHUNK_STREAM.pop
    window << c
    if window.size == CHUNKS_PER_BUFFER
      windows << window

      if windows.size == 38
        data = windows.map do |w|
          d = {}
          methods.each {|k, fn| d[k] = fn.call(w) }
          d
        end

        new_data = []
        data.each_slice(2) do |d1, d0|
          new_data << d1
          new_data << d0
          dr = {}
          method_names.each do |k|
            ratio = (d1[k].to_f / d0[k])
            dr[k] = ratio.round
            method_results[:highs][k]  ||= []
            method_results[:highs][k]  << d1[k]
            method_results[:lows][k]   ||= []
            method_results[:lows][k]   << d0[k]
            method_results[:ratios][k] ||= []
            method_results[:ratios][k] << ratio
          end
          new_data << dr
          new_data << nil
        end

        fmt_s = Array.new(method_names.size, "%10s").join(" ") + "\n\n"
        fmt_d = Array.new(method_names.size, "%10d").join(" ") + "\n"
        fmt_f = Array.new(method_names.size, "%10.2f").join(" ") + "\n"

        puts ""
        printf fmt_s, *method_names
        new_data.each do |d|
          if d
            printf fmt_d, *method_names.map {|k| d[k] }
          else
            puts ""
          end
        end

        highs  = method_results[:highs]
        lows   = method_results[:lows]
        ratios = method_results[:ratios]

        puts "mean of highs"
        printf fmt_d, *method_names.map {|k| mean(highs[k]) }
        puts ""

        puts "standard deviation of highs"
        printf fmt_f, *method_names.map {|k| standard_deviation_ratio(highs[k]) }
        puts ""

        puts "mean of lows"
        printf fmt_d, *method_names.map {|k| mean(lows[k]) }
        puts ""

        puts "standard deviation of lows"
        printf fmt_f, *method_names.map {|k| standard_deviation_ratio(lows[k]) }
        puts ""

        puts "mean of ratios"
        printf fmt_d, *method_names.map {|k| mean(ratios[k]) }
        puts ""

        puts "harmonic mean of ratios"
        printf fmt_d, *method_names.map {|k| harmonic_mean(ratios[k]) }
        puts ""

        puts "standard deviation of ratios"
        printf fmt_f, *method_names.map {|k| standard_deviation_ratio(ratios[k]) }
        puts ""

        puts "# ratios below 5"
        printf fmt_d, *method_names.map {|k| ratios[k].select {|r| r < 5 }.size }
        puts ""

        puts "# ratios below 2"
        printf fmt_d, *method_names.map {|k| ratios[k].select {|r| r < 2 }.size }
        puts ""

        printf fmt_s, *method_names
      end

      window = []
    end
  end
end

BUF.start
sleep 2
BUF.stop

listen_thread.kill.join
process_thread.kill.join

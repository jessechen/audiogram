require "coreaudio"
require "fftw3"
require "./constants"

Thread.abort_on_exception = true

PEAK_INDICES = FREQUENCIES.map do |f|
  i = (f.to_f / RATE * CHUNK_SIZE).round
  arr = (i-SUM_DISTANCE_FROM_PEAK..i+SUM_DISTANCE_FROM_PEAK).to_a
  arr + arr.map {|x| 1024 - x }
end

buf = CoreAudio.default_input_device.input_buffer(BUFFER_SIZE)
MEASUREMENT_STREAM = Queue.new

def highest_signal(occurrences)
  return 0 unless occurrences.any?
  occurrences.max_by {|_, v| v}.first
end

def confidence(window, bit)
  # exact = 1
  # with others = 1/N
  # just others = -N
  # nothing = 0
  window.reduce(0) {|acc, bits| acc + (bits.include?(bit) ? 1/bits.size : -bits.size) }.to_f / window.size
end

def bits_to_char(bit_array)
  byte = bit_array.reduce(0) {|acc, bit| (acc << 1) + bit}
  [byte].pack("c")
end

def process_chunk(chunk)
  fft = FFTW3.fft(chunk).real.abs
  arr = fft.to_a
  area_under_peaks = PEAK_INDICES[1].map {|i| arr[i] }.inject(&:+)

  print_to_graph(chunk, fft, area_under_peaks)
  MEASUREMENT_STREAM.push(area_under_peaks)
end

def print_to_graph(chunk, fft, aup)
  $iter = ($iter || 0) + 1
  chunk = chunk.to_a
  fft = fft.to_a
  sum = fft.inject(&:+)
  avg = sum / fft.size
  max = fft.max
  File.open("js/data#{$iter}.json", "w") do |f|
    text = "sum: #{sum.round}, avg: #{avg.round}, max: #{max.round}, aup: #{aup.round}"
    f << "{\"fft\":" + fft.inspect + ", \"signal\":" + chunk.inspect + ", \"text\": \"" + text + "\" }"
  end
end

listen_thread = Thread.start do
  loop do
    waveform = buf.read(BUFFER_SIZE)
    channel = waveform[0, true]
    (0...CHUNKS_PER_BUFFER).each do |i|
      start = i*CHUNK_SIZE
      chunk = channel[start...(start+CHUNK_SIZE)]
      process_chunk(chunk)
    end
  end
end

process_thread = Thread.start do
  # calibrate
  window = Array.new(CHUNKS_PER_BUFFER, 0)
  while m = MEASUREMENT_STREAM.pop
    window = window[1..-1]
    window << m
    average_m = window.inject(&:+) / window.size
    if average_m > CALIBRATION_THRESHOLD
      puts "calibrated"
      MEASUREMENT_STREAM.pop
      break
    end
  end

  # we're calibrated
  window = []
  while m = MEASUREMENT_STREAM.pop
    window << m
    if window.size >= CHUNKS_PER_BUFFER
      average_m = window.inject(&:+) / window.size
      bit = average_m > BIT_THRESHOLD ? 1 : 0
      puts "bit: #{bit} (m: #{average_m.round})"
      window = []
    end
  end
end

buf.start
sleep 5
buf.stop

listen_thread.kill.join
process_thread.kill.join

DOT = "·"
DASH = "–"
END_OF_WORD = [0, 0, 0, 0, 0, 0, 0]

MORSE_DECODE = {
  [DOT,  DASH]                   => 'A',
  [DASH, DOT,  DOT,  DOT ]       => 'B',
  [DASH, DOT,  DASH, DOT ]       => 'C',
  [DASH, DOT,  DOT ]             => 'D',
  [DOT ]                         => 'E',
  [DOT,  DOT,  DASH, DOT ]       => 'F',
  [DASH, DASH, DOT ]             => 'G',
  [DOT,  DOT,  DOT,  DOT ]       => 'H',
  [DOT,  DOT ]                   => 'I',
  [DOT,  DASH, DASH, DASH]       => 'J',
  [DASH, DOT,  DASH]             => 'K',
  [DOT,  DASH, DOT,  DOT ]       => 'L',
  [DASH, DASH]                   => 'M',
  [DASH, DOT ]                   => 'N',
  [DASH, DASH, DASH]             => 'O',
  [DOT,  DASH, DASH, DOT ]       => 'P',
  [DASH, DASH, DOT,  DASH]       => 'Q',
  [DOT,  DASH, DOT ]             => 'R',
  [DOT,  DOT,  DOT ]             => 'S',
  [DASH]                         => 'T',
  [DOT,  DOT,  DASH]             => 'U',
  [DOT,  DOT,  DOT,  DASH]       => 'V',
  [DOT,  DASH, DASH]             => 'W',
  [DASH, DOT,  DOT,  DASH]       => 'X',
  [DASH, DOT,  DASH, DASH]       => 'Y',
  [DASH, DASH, DOT,  DOT ]       => 'Z',
  [DASH, DASH, DASH, DASH, DASH] => '0',
  [DOT,  DASH, DASH, DASH, DASH] => '1',
  [DOT,  DOT,  DASH, DASH, DASH] => '2',
  [DOT,  DOT,  DOT,  DASH, DASH] => '3',
  [DOT,  DOT,  DOT,  DOT,  DASH] => '4',
  [DOT,  DOT,  DOT,  DOT,  DOT ] => '5',
  [DASH, DOT,  DOT,  DOT,  DOT ] => '6',
  [DASH, DASH, DOT,  DOT,  DOT ] => '7',
  [DASH, DASH, DASH, DOT,  DOT ] => '8',
  [DASH, DASH, DASH, DASH, DOT ] => '9',
}

MORSE_ENCODE = MORSE_DECODE.invert

def decode(morse_signals)
  MORSE_DECODE[morse_signals] || '?'
end

def bits_to_signals(bits)
  # dot = 1x1
  # dash = 1x3
  # end_of_signal = 0x1
  # end_of_char = 0x3
  # end_of_word = 0x7

  bits.gsub!(/0{3,}/, ' ')  # 3 or more consecutive zeros
  bits.gsub!(/1{3,}/, DASH) # 3 or more consecutive ones
  bits.gsub!(/1+/, DOT)
  bits.gsub!(/0+/, '')
  bits.split(' ').map {|s| s.chars}
end

def encode(string)
  string.upcase.tr('^A-Z0-9', '').chars.map {|char| MORSE_ENCODE[char]}
end

def signals_to_bits(signals)
  signals.map do |signal|
    signal.join('0').gsub(DOT, '1').gsub(DASH, '111')
  end.join('000').chars.map(&:to_i)
end

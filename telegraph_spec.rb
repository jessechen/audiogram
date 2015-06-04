require './telegraph'

describe 'telegraph' do
  it 'should decode morse signal arrays' do
    expect(decode([DOT])).to eq('E')
    expect(decode([DOT, DOT, DOT])).to eq('S')
    expect(decode([DASH, DOT, DOT, DOT, DOT])).to eq('6')
    expect(decode([DOT, DOT, DASH, DASH])).to eq('?')
  end

  it 'should convert bits into morse signal arrays' do
    expect(bits_to_signals "1").to eq([[DOT]])
    expect(bits_to_signals "111").to eq([[DASH]])
    expect(bits_to_signals "101").to eq([[DOT, DOT]])
    expect(bits_to_signals "10111").to eq([[DOT, DASH]])
  end

  it 'should split characters on runs of three zeros' do
    expect(bits_to_signals "10001").to eq([[DOT], [DOT]])
    expect(bits_to_signals "111010001110001").to eq([[DASH, DOT], [DASH], [DOT]])
  end

  it 'should treat runs of two ones as dots and runs of four or more ones as dashes' do
    expect(bits_to_signals "11").to eq([[DOT]])
    expect(bits_to_signals "1111").to eq([[DASH]])
    expect(bits_to_signals "111110011").to eq([[DASH, DOT]])
    expect(bits_to_signals "11111000011").to eq([[DASH], [DOT]])
  end

  it 'should encode strings to morse signal arrays' do
    expect(encode('E')).to eq([[DOT]])
    expect(encode('Q')).to eq([[DASH, DASH, DOT, DASH]])
    expect(encode('HI')).to eq([[DOT, DOT, DOT, DOT], [DOT, DOT]])
  end

  it "should upcase strings and ignore characters it doesn't know" do
    expect(encode('e²')).to eq([[DOT]])
    expect(encode('hi?')).to eq([[DOT, DOT, DOT, DOT], [DOT, DOT]])
    expect(encode('u2')).to eq([[DOT, DOT, DASH], [DOT, DOT, DASH, DASH, DASH]])
  end
end
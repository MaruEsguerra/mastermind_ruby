class Code
  attr_reader :sequence
  
  VALID_COLORS = ["R", "O", "Y", "G", "B", "I", "V"]

  def initialize(sequence = nil)
    @sequence = sequence || generate
  end

  def generate
    # Generates random 4-color code from valid colors
    Array.new(4) { VALID_COLORS.sample }
  end

  def self.from_player_input
    puts "Create your secret code using these colors: #{VALID_COLORS.join(', ')}."
    puts "Enter 4 colors separated by spaces (ex. R G B Y): "

    loop do
      input = gets.chomp.upcase.split
      if valid_sequence?(input)
        return new(input)
      else
        puts "Invalid code! Please use exactly 4 colors from #{VALID_COLORS.join(', ')}."
      end
    end
  end

  def evaluate_guess(guess)
    # Evaluates guesses and returns feedback: black/white pegs
    code_copy = @sequence.dup
    guess_copy = guess.dup

    black = 0
    white = 0

    # First pass: check for black pegs
    4.times do |i|
      if guess_copy[i] == code_copy[i]
        black += 1
        guess_copy[i] = nil # Mark as processed
        code_copy[i] = nil  # Mark as processed
      end
    end

    # Second pass: check for white pegs
    4.times do |i|
      next unless guess_copy[i] # Skip already processed positions
        
      idx = code_copy.index(guess_copy[i])
      if idx
        white += 1
        code_copy[idx] = nil  # Mark the color as used
      end
    end

    # Returned feedback
    { black: black, white: white}
  end

  def correct_guess?(guess)
    guess == @sequence
  end

  def self.valid_sequence?(sequence)
    sequence.size == 4 && sequence.all? { |color| VALID_COLORS.include?(color) }
  end
end

class ComputerPlayer
  def initialize
    @confirmed_positions = Array.new(4)          # Positions the computer is 100% sure about
    @wrong_colors = []                           # Colors not in the code
    @candidate_colors = Code::VALID_COLORS.dup   # Colors that might be in the code
    @previous_guesses = []
  end
  
  def make_guess
    # Start with what the computer knows for sure
    guess = @confirmed_positions.dup

    # Fill in the blanks
    4.times do |position|
      next if guess[position] # Skip known positions

      # Pick from colors not eliminated
      available = @candidate_colors - guess.compact - @wrong_colors
      guess[position] = available.sample || Code::VALID_COLORS.sample
    end

    guess
  end

  def learn_from_feedback(guess, feedback)
    @previous_guesses << { guess: guess.dup, feedback: feedback }

    black_pegs = feedback[:black]
    white_pegs = feedback[:white]
    total_correct = black_pegs + white_pegs

    # Simple rule: if no colors match, eliminate all of it
    if total_correct == 0
      @wrong_colors.concat(guess)
      @wrong_colors.uniq!
      @candidate_colors -= guess
      return
    end

    # If all black pegs, computer solved it!
    if black_pegs == 4
      4.times { |i| @confirmed_positions[i] = guess[i] }
    end

    # Modified rule: Give computer hints
    if black_pegs > 0
      identify_some_correct_positions(guess, feedback)
    end
  end

  private

  def identify_some_correct_positions(guess, feedback)
    # Compare guess with previous ones to find patterns
    return if @previous_guesses.length < 2

    # Find previous guesses
    previous = @previous_guesses[-2]
    prev_guess = previous[:guess]
    prev_feedback = previous[:feedback]

    # If black pegs increased and only one position changed, position is correct
    differences = []
    4.times do |i|
      differences << i if guess[i] != prev_guess[i]
    end

    # Make conclusions when one thing changed
    if differences.length == 1
      changed_pos = differences.first

      if feedback[:black] > prev_feedback[:black]
        # Gained pegs from changing position, so likely correct
        puts "Computer thinks: '#{guess[changed_pos]}' belongs at position #{changed_pos + 1}."
        @confirmed_positions[changed_pos] = guess[changed_pos]
      elsif feedback[:black] < prev_feedback[:black]
        # Lost black pegs, so old color correct
        puts "Computer thinks: '#{prev_guess[changed_pos]}' belongs at position #{changed_pos + 1}."
        @confirmed_positions[changed_pos] = prev_guess[changed_pos]
      end
    end
  end
end

class HumanPlayer
  def initialize(name)
    @name = name
  end

  def make_guess
    puts "#{@name}, enter your guess (ex. R G B Y): "
    gets.chomp.upcase.split
  end

  def create_code
    Code.from_player_input
  end
end

class Board
  def initialize
    @turns = [] # Each turn is [guess, feedback]
  end

  def add_turn(guess, feedback)
    @turns << [guess, feedback]
  end

  def display
    puts "--- BOARD ---"
    if @turns.empty?
      puts "No guesses yet."
    else
      @turns.each_with_index do |(guess, feedback), i|
        puts "Turn #{i + 1}: #{guess.join(' ')} | #{format_feedback(feedback)}"
      end
    end
    puts "-------------"
  end

  private

  def format_feedback(feedback)
    if feedback.is_a?(Hash)
      "#{feedback[:black]} black peg(s), #{feedback[:white]} white peg(s)."
    end
  end
end

class Game
  MAX_TURNS = 12

  def initialize
    @board = Board.new
    @human_player = HumanPlayer.new("Player")
    @computer_player = ComputerPlayer.new
  end

  def play
    puts "Welcome to Mastermind!"
    puts "The available colors are: #{Code::VALID_COLORS.join(', ')}."
    puts "Game Rules:"
    puts "Black peg = correct color in the correct position."
    puts "White peg = correct color in the wrong position."
    puts "You have #{MAX_TURNS} turns to crack the code!"
    
    mode = get_game_mode

    case mode
    when 1
      play_human_guesses
    when 2
      play_computer_guesses
    end
  end

  private
  
  def get_game_mode
    puts "Choose your game mode:"
    puts "1: You guess the computer's secret code;"
    puts "2: The computer guesses your secret code!"

    loop do
      print "Either 1 or 2: "
      mode = gets.chomp.to_i
      return mode if [1, 2].include?(mode)
      puts "Please enter either 1 or 2."
    end
  end

  def play_human_guesses
    puts "The computer has created a secret code. Try to crack it!"
    code = Code.new # The computer generates random code

    MAX_TURNS.times do |turn_num|
      puts "--- Turn #{turn_num + 1} of #{MAX_TURNS} ---"

      guess = get_valid_guess_from_human
      feedback = code.evaluate_guess(guess)
      @board.add_turn(guess, feedback)
      @board.display

      if code.correct_guess?(guess)
        puts "Congratulations! You cracked the code in #{turn_num + 1} turn(s)!"
        return
      elsif feedback[:black] > 0 || feedback[:white] > 0
        puts "Good progress! Keep going!"
      end
    end

    puts "Game Over! You ran out of turns."
    puts "The secret code was: #{code.sequence.join(' ')}."
  end

  def play_computer_guesses
    puts "You are the codemaker! Create your secret code."
    code = @human_player.create_code
    puts "Great! Your secret code is set. Let's see if the computer can crack it!"

    MAX_TURNS.times do |turn_num|
      puts "--- Turn #{turn_num + 1} of #{MAX_TURNS} ---"

      guess = @computer_player.make_guess
      puts "Computer guesses: #{guess.join(' ')}"

      feedback = code.evaluate_guess(guess)
      @computer_player.learn_from_feedback(guess, feedback)
      @board.add_turn(guess, feedback)
      @board.display

      if code.correct_guess?(guess)
        puts "The computer cracked your code in #{turn_num + 1} turn(s)!"
        puts "Your secret code was: #{code.sequence.join(' ')}."
        return
      end

      # Adds small delay for intrigue
      puts "Computer is thinking..." if turn_num < MAX_TURNS - 1
      sleep(1)
    end

    puts "Congratulations! The computer couldn't crack your code!"
    puts "Your secret code was: #{code.sequence.join(' ')}."
  end
  
  def get_valid_guess_from_human
    loop do
      guess = @human_player.make_guess
      return guess if valid_guess?(guess)
      puts "Invalid guess! Please use exactly 4 letters from: #{Code::VALID_COLORS.join(', ')}."
    end
  end

  def valid_guess?(guess)
    guess.size == 4 && guess.all? { |color| Code::VALID_COLORS.include?(color) }
  end

end

game = Game.new
game.play
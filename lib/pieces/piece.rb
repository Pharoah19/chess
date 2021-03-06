class Piece
	attr_accessor :board, :position, :faction, :legal_moves
	attr_writer :moved

	def initialize(board, faction, x, y, moved = false)
		@board = board
		@position = [x, y]		
		@faction = faction
		@legal_moves = []
		@moved = moved
		board.set(self, x, y)		
	end

	def moved?
		@moved
	end

	def move(x, y)		
		return false unless show_legal_moves.include? [x, y]
		return false unless safe_moves.include? [x, y]
		proceed(x, y)
		true	
	end

	def proceed(x, y)
		self.moved = true
		board.move(*position, x, y)
	end

	def show_legal_moves
		find_legal_moves
		legal_moves
	end

	def safe_moves
		legal_moves.select do |move|
			board.simulate_move(self, *move)
		end
	end

	def copy_to(another_board)
		self.class.new(another_board, faction, *position, moved?)
	end

	def find_legal_moves
		self.legal_moves = []
		(1..8).to_a.repeated_permutation(2) do |pair|
			legal_moves << pair
		end
	end

	def friendly?(x, y)
		return false if board.get(x, y).nil?
		board.get(x, y).faction == faction
	end

	def enemy?(x, y)
		return false if board.get(x, y).nil?
		board.get(x, y).faction != faction
	end
end
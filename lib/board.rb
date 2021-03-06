require "set"

class Board
	attr_accessor :grid, :kings, :captures, :pieces_in_play, :game, :previous_turn

	def initialize(game = nil)
		@grid = Array.new(8) { Array.new(8) }
		@kings = {}
		@previous_turn = nil
		@captures = Hash.new { |hsh, key| hsh[key] = [] }
		@pieces_in_play = Set.new
		@game = game
	end

	def get(x, y)
		grid[x - 1][y - 1]
	end

	def set(piece, x, y)
		update_captures(piece, x, y)
		place(piece, x, y)
		handle_promotion(piece, x, y)
		handle_castling(piece, x, y)
	end

	def move(x1, y1, x2, y2)
		piece = get(x1, y1)
		self.previous_turn = piece.faction
		set(nil, x1, y1)		
		set(piece, x2, y2)
		disable_en_passant
	end

	def handle_promotion(piece, x, y)
		if pawn_promotion?(piece, x, y)
			place(nil, x, y)
			promote_to(choose_promotion, piece.faction, x, y)
		end
	end

	def promote_to(selection, faction, x, y)
		Queen.new(self, faction, x, y) unless %w(r b n).include?(selection)
		Rook.new(self, faction, x, y) if selection == "r"
		Bishop.new(self, faction, x, y)if selection == "b"
		Knight.new(self, faction, x, y)if selection == "n"
	end

	def pawn_promotion?(piece, x, y)
		piece.class == Pawn && [1, 8].include?(y)
	end

	def choose_promotion
		return if game.nil?
		game.active_player_puts "Choose a piece queen (default), [b]ishop, [r]ook or k[n]ight. "
		game.active_player_input
	end

	def handle_castling(piece, x, y)
		if castling?(piece, x, y)
			move_rook(y, 8, 6) if x == 7
			move_rook(y, 1, 4) if x == 3
		end
	end

	def move_rook(y, rook_x1, rook_x2)
		rook = get(rook_x1, y)				
		place(nil, rook_x1, y)
		place(rook, rook_x2, y)
	end

	def update_captures(piece, x, y)
		if en_passant?(piece, x, y) then en_passant_capture(piece, x, y)
		else ordinary_capture(piece, x, y)
		end		
	end

	def en_passant_capture(piece, x, y)
		captures[piece.faction] << get(*piece.en_passant_capture_cell)
		place(nil, *piece.en_passant_capture_cell)
	end

	def ordinary_capture(piece, x, y)
		captures[piece.faction] << get(x, y) unless piece.nil? || get(x, y).nil?
	end

	def disable_en_passant
		pieces_in_play.select { |piece| piece.class == Pawn }.each do |pawn|  
			pawn.en_passant_cell = nil
		end
	end

	def place(piece, x, y)
		update_pieces(piece, x, y)
		piece.position = [x, y] unless piece.nil?		
		self.kings[piece.faction] = [x, y] if piece.class == King
		self.grid[x - 1][y - 1] = piece
	end

	def update_pieces(piece, x, y)
		pieces_in_play << piece unless piece.nil?
		pieces_in_play.delete(get(x, y)) unless get(x, y).nil?
	end

	def copy
		new_board = self.class.new
		copy_pieces_to(new_board)
		new_board.previous_turn = previous_turn
		new_board
	end

	def copy_pieces_to(new_board)
		pieces_in_play.each { |piece| piece.copy_to(new_board) }
		new_board
	end

	def simulate_move(piece, x, y)
		return simulate_castling(piece, x, y) if castling?(piece, x, y)
		simulation(piece, x, y)
	end

	def simulation(piece, x, y)
		simulation_board = copy
		simulation_board.move(*piece.position, x, y)
		return !simulation_board.checked?(piece.faction)
	end

	def castling?(piece, x, y)
		piece.class == King && !piece.castling_cells.empty? && piece.castling_cells.include?([x, y])
	end

	def en_passant?(piece, x, y)
		piece.class == Pawn && !piece.en_passant_cell.nil? && piece.en_passant_cell == [x, y]
	end

	def simulate_castling(piece, x, y)
		middle_cell = x == 7 ? [6, y] : [4, y]
		not_checked = !checked?(piece.faction)	
		middle_cell_not_checked = simulation(piece, *middle_cell)
		destination_cell_not_checked = simulation(piece, x, y)
		not_checked  &&middle_cell_not_checked &&destination_cell_not_checked
	end

	def enemies(faction)
		pieces_in_play.reject { |piece| piece.faction == faction }
	end

	def friendlies(faction)
		pieces_in_play.select { |piece| piece.faction == faction }
	end

	def enemy_moves(faction)
		enemies(faction).reduce(Set.new) { |moves, piece| moves += piece.show_legal_moves }
	end

	def friendly_moves(faction)
		friendlies(faction).reduce(Set.new) { |moves, piece| moves += piece.show_legal_moves }
	end

	def no_moves?(faction)
		friendlies(faction).each do |piece|
			piece.find_legal_moves
			return false unless piece.safe_moves.empty?
		end
	end

	def available_moves(faction)
		moves = {}
		friendlies(faction).each do |piece|
			piece.find_legal_moves
			moves[piece.position] = piece.safe_moves unless piece.safe_moves.empty?
		end
		moves
	end

	def checkmate?(faction)
		no_moves?(faction) && checked?(faction)
	end

	def stalemate?(faction)
		no_moves?(faction) && !checked?(faction)
	end

	def dead_position?
		king_vs_king_and_bishop_or_knight? || kings_and_bishops_of_same_color_square?
	end

	def kings_and_bishops_of_same_color_square?
		all_kings_and_bishops? && all_bishops_on_same_square_color?
	end

	def all_kings_and_bishops?
		pieces_in_play.all? { |piece| piece.class == King || piece.class == Bishop }
	end

	def all_bishops_on_same_square_color?
		square = nil
		pieces_in_play.select { |piece| piece.class == Bishop }.all? do |bishop|
			square ||= (bishop.position[0] + bishop.position[1]).even?
			square == (bishop.position[0] + bishop.position[1]).even?
		end
	end

	def king_vs_king_and_bishop_or_knight?
		pieces_in_play.all? { |piece| piece.class == King || piece.class == Bishop || piece.class == Knight	} &&
		pieces_in_play.size <= 3
	end

	def checked?(faction)
		enemy_moves(faction).include? kings[faction]
	end

	def occupied_cells
		pieces_in_play.map { |piece| piece.position }
	end

	def show
		show_captures(:black) + column_labels + rows_with_labels + div + column_labels + show_captures(:white)
	end

	def show_reversed
		show_captures(:white) + column_labels(true) + rows_with_labels(true) + div + column_labels(true) + show_captures(:black)
	end

	def show_captures(faction)		
		(captures[faction].map { |piece| piece.to_s }.sort.join(" ").prepend "  ") + "\n"
	end

	def div
		"   " + ("+" * 9).split(//).join("---") + "\n"
	end

	def column_labels(reversed = false)
		labels = ("A".."H").to_a
		labels.reverse! if reversed
		output = "  "
		labels.each { |column| output += "   #{column}" }
		output + "\n"
	end

	def rows_with_labels(reversed = false)
		labels = 8.downto(1).to_a
		labels.reverse! if reversed
		output = ""
		labels.each {  |row|	output += row_with_label(row, labels.reverse) }
		output
	end

	def row_with_label(row, order)
		output = "#{div} #{row} "
		order.each { |column| output += (get(column, row).nil? ? "|   " : "| #{get(column, row)} ")	}
		output + "| #{row}\n"
	end

end

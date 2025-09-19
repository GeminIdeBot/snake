```bash
#!/bin/bash

# --- Configuration ---
WIDTH=40
HEIGHT=20
SNAKE_CHAR="#"
FOOD_CHAR="@"
WALL_CHAR="X"
EMPTY_CHAR=" "
GAME_SPEED=0.15 # seconds (lower value = faster game)

# --- Global Variables ---
snake_x=()    # Array for snake X coordinates
snake_y=()    # Array for snake Y coordinates
food_x=
food_y=
score=0
direction="right" # Current snake direction: up, down, left, right
game_over=0
input_buffer="" # Used to capture multi-character arrow key sequences

# --- Terminal Setup/Teardown ---

# Function to set up terminal for game
setup_terminal() {
    tput clear      # Clear the screen
    tput civis      # Hide the cursor
    stty -echo      # Turn off echoing of input characters
    stty raw        # Read characters instantly without waiting for Enter
}

# Function to restore terminal settings
restore_terminal() {
    stty echo       # Turn on echoing
    stty -raw       # Restore normal input behavior
    tput cnorm      # Show the cursor
    tput sgr0       # Reset terminal colors/attributes
    echo            # Print a newline to ensure clean prompt after exit
}

# --- Game Functions ---

# Initialize game state: snake position, food, score, direction
init_game() {
    # Initial snake (3 segments, starting in the middle, moving right)
    snake_x=( $((WIDTH / 2)) $((WIDTH / 2 - 1)) $((WIDTH / 2 - 2)) )
    snake_y=( $((HEIGHT / 2)) $((HEIGHT / 2)) $((HEIGHT / 2)) )

    spawn_food # Place initial food
    score=0
    direction="right"
    game_over=0
}

# Spawn food at a random valid location (not on snake or wall)
spawn_food() {
    local valid_pos=0
    while [[ $valid_pos -eq 0 ]]; do
        # Generate random coordinates within the playable area (excluding walls)
        food_x=$((RANDOM % (WIDTH - 2) + 1))
        food_y=$((RANDOM % (HEIGHT - 2) + 1))

        valid_pos=1
        # Check if food is on any part of the snake
        for i in "${!snake_x[@]}"; do
            if [[ ${snake_x[$i]} -eq $food_x && ${snake_y[$i]} -eq $food_y ]]; then
                valid_pos=0 # Food is on snake, try again
                break
            fi
        done
    done
}

# Draw the game board, snake, and food to the terminal
draw_game() {
    tput cup 0 0 # Move cursor to the top-left corner (row 0, col 0)

    # Draw top wall
    for ((x=0; x<WIDTH; x++)); do
        echo -n "$WALL_CHAR"
    done
    echo

    # Draw middle rows (walls, empty space, snake, food)
    for ((y=1; y<HEIGHT-1; y++)); do
        echo -n "$WALL_CHAR" # Left wall
        for ((x=1; x<WIDTH-1; x++)); do
            local printed=0

            # Check if current (x,y) is part of the snake
            for i in "${!snake_x[@]}"; do
                if [[ ${snake_x[$i]} -eq $x && ${snake_y[$i]} -eq $y ]]; then
                    echo -n "$SNAKE_CHAR"
                    printed=1
                    break
                fi
            done
            if [[ $printed -eq 1 ]]; then continue; fi

            # Check if current (x,y) is the food
            if [[ $x -eq $food_x && $y -eq $food_y ]]; then
                echo -n "$FOOD_CHAR"
                printed=1
            fi
            if [[ $printed -eq 1 ]]; then continue; fi

            # If nothing else, it's an empty space
            echo -n "$EMPTY_CHAR"
        done
        echo "$WALL_CHAR" # Right wall
    done

    # Draw bottom wall
    for ((x=0; x<WIDTH; x++)); do
        echo -n "$WALL_CHAR"
    done
    echo

    # Display current score
    echo "Score: $score"
}

# Read user input for direction (non-blocking, handles arrow keys and WASD)
read_input() {
    local char
    input_buffer="" # Clear buffer for this iteration

    # Read the first character with a timeout. If no char is entered within
    # GAME_SPEED, 'read' returns non-zero, and the loop effectively pauses.
    # If a char is read, game continues instantly.
    if read -s -n 1 -t $GAME_SPEED char; then
        input_buffer+="$char"
    else
        return # No input, just return and let the snake move
    fi

    # Handle multi-character arrow key sequences (e.g., ESC [ A)
    # If the first char is ESC, try to read the next two characters very quickly
    if [[ "$input_buffer" == $'\x1b' ]]; then
        if read -s -n 1 -t 0.001 char; then # Short timeout to get next char
            input_buffer+="$char"
            if [[ "$input_buffer" == $'\x1b[' ]]; then
                if read -s -n 1 -t 0.001 char; then # Short timeout to get final char
                    input_buffer+="$char"
                fi
            fi
        fi
    fi

    # Process the gathered input
    case "$input_buffer" in
        $'\x1b[A'|'w'|'W') # Up arrow or 'w'
            if [[ "$direction" != "down" ]]; then direction="up"; fi ;;
        $'\x1b[B'|'s'|'S') # Down arrow or 's'
            if [[ "$direction" != "up" ]]; then direction="down"; fi ;;
        $'\x1b[C'|'d'|'D') # Right arrow or 'd'
            if [[ "$direction" != "left" ]]; then direction="right"; fi ;;
        $'\x1b[D'|'a'|'A') # Left arrow or 'a'
            if [[ "$direction" != "right" ]]; then direction="left"; fi ;;
        'q'|'Q') # Quit game
            game_over=1 ;;
    esac
}

# Update game state: move snake, check collisions, handle food
update_game() {
    local head_x=${snake_x[0]} # Current head X
    local head_y=${snake_y[0]} # Current head Y

    local new_head_x=$head_x
    local new_head_y=$head_y

    # Calculate new head position based on current direction
    case "$direction" in
        "up")    new_head_y=$((new_head_y - 1)) ;;
        "down")  new_head_y=$((new_head_y + 1)) ;;
        "left")  new_head_x=$((new_head_x - 1)) ;;
        "right") new_head_x=$((new_head_x + 1)) ;;
    esac

    # --- Collision Detection ---

    # 1. Collision with wall
    if [[ $new_head_x -eq 0 || $new_head_x -eq $((WIDTH - 1)) || \
          $new_head_y -eq 0 || $new_head_y -eq $((HEIGHT - 1)) ]]; then
        game_over=1
        return
    fi

    # 2. Collision with self (new head position matches any existing snake body segment)
    for i in "${!snake_x[@]}"; do
        if [[ $new_head_x -eq ${snake_x[$i]} && $new_head_y -eq ${snake_y[$i]} ]]; then
            game_over=1
            return
        fi
    done

    # --- Food Check / Snake Movement ---

    # Check if the new head position is on the food
    if [[ $new_head_x -eq $food_x && $new_head_y -eq $food_y ]]; then
        score=$((score + 1)) # Increase score
        spawn_food           # Place new food
    else
        # If no food eaten, remove the tail segment to simulate movement
        unset 'snake_x[${#snake_x[@]}-1]' # Remove last element
        unset 'snake_y[${#snake_y[@]}-1]'
        snake_x=("${snake_x[@]}") # Re-index arrays after unset
        snake_y=("${snake_y[@]}")
    fi

    # Add the new head position to the beginning of the snake arrays
    snake_x=("$new_head_x" "${snake_x[@]}")
    snake_y=("$new_head_y" "${snake_y[@]}")
}

# --- Main Game Loop ---

# Ensure terminal settings are restored even if script is interrupted (e.g., Ctrl+C)
trap restore_terminal EXIT

setup_terminal # Prepare the terminal
init_game      # Initialize game state

while [[ $game_over -eq 0 ]]; do
    read_input  # Read user input
    update_game # Update game state (move snake, check collisions, etc.)
    draw_game   # Redraw the game board
done

# --- Game Over Screen ---
tput cup $((HEIGHT / 2)) $((WIDTH / 2 - 5)) # Position cursor roughly center for "GAME OVER!"
echo "GAME OVER!"
tput cup $((HEIGHT / 2 + 1)) $((WIDTH / 2 - 7)) # Position cursor for score
echo "Final Score: $score"
tput cup $((HEIGHT + 2)) 0 # Move cursor below game area before final exit
sleep 2 # Pause briefly to show the "Game Over" message

restore_terminal # Restore original terminal settings
exit 0
```
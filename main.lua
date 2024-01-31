-- Import necessary libraries
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/crank"

local pd <const> = playdate
local gfx <const> = pd.graphics
local sound <const> = pd.sound -- Access the sound module

local errorMessage = nil -- Variable to hold the error message
local errorTimer = 0 -- Timer to control the display duration of the error message

-- Load background images
local entrance_bg_image = gfx.image.new("images/entrance_bg")
assert(entrance_bg_image) -- Make sure the image is loaded correctly
local forest_bg_image = gfx.image.new("images/forest_bg")
assert(forest_bg_image) -- Make sure the image is loaded correctly

-- Load audio files
local titleScreenSong = sound.sampleplayer.new("audio/intro") -- Replace with the actual path to your audio file
local buttonPressSound = sound.sampleplayer.new("audio/Start") -- Replace with the actual path to your audio file

local lastCrankAngle = 0 -- Initialize lastCrankAngle to 0

local function getCrankAngle()
    if playdate.crankGetAngle then
        return playdate.crankGetAngle()
    else
        return lastCrankAngle -- Return the last known crank angle if crankGetAngle is not available
    end
end

-- Use getCrankAngle function instead of playdate.crankGetAngle
local crankAngle = getCrankAngle()
local delta = crankAngle - lastCrankAngle

local orientation = "none" -- default orientation

-- Define a game state
local game = {
    showTitleScreen = true, -- New flag for the title screen
    showMap = false
}

-- Define the player's position and orientation
local player = {
    x = 0,
    y = 0,
    orientation = "north",
    inventory = {}, -- Player's inventory
    health = 100, -- Player's health for combat
    level = 1 -- Player's level for progression
}

-- Define the relative directions
local relativeDirections = {
    forward = "north",
    backward = "south",
    left = "west",
    right = "east"
}

-- Define the rooms
local rooms = {
    entrance = {
        description = "Welcome to WalMart. The fluorescent lights buzz above you and the smell of freshly made popcorn fills your nose, although you can't see a popcorn machine anywhere..",
        north = "toys",
        south = "electronics",
        east = "grocery",
        west = "clothing"
    },
    toys = {
        description = "You are surrounded by a variety of toys, from action figures to board games.",
        north = "treasure_room",
        south = "parking_lot",
        east = "monster_room",
        west = "back_room"
    },
    electronics = {
        description = "Electronic devices of all kinds line the shelves: phones, TVs, and more.",
        north = "parking_lot",
        south = "treasure_room",
        east = "back_room",
        west = "monster_room"
    },
    grocery = {
        description = "Aisles of food stretch out before you. It smells like fresh produce.",
        north = "monster_room",
        south = "back_room",
        east = "treasure_room",
        west = "parking_lot"
    },
    clothing = {
        description = "Clothes for all seasons are on display, from swimsuits to winter coats.",
        north = "back_room",
        south = "monster_room",
        east = "parking_lot",
        west = "treasure_room"
    },
    treasure_room = {
        description = "You've found the treasure room! Congratulations!"
    },
    monster_room = {
        description = "A monster attacks you, you died!"
    },
    parking_lot = {
        description = "You've been robbed!"
    },
    back_room = {
        description = "You've entered the backrooms and left this dimension. Say goodbye to the life you once knew"
    }
}

-- Initialize the current room to the entrance
local current_room = rooms.entrance

-- Define the alphabet and the current letter index
local alphabet = "abcdefghijklmnopqrstuvwxyz"
local directions = {"north", "south", "east", "west"}
local currentLetterIndex = 1
local currentDirectionIndex = 1
local isPopupVisible = false
local currentInput = "" -- Variable to hold the current input string
local ditherPattern = nil -- Define ditherPattern as a global variable

-- Define a variable to keep track of the slideshow index for each orientation
local slideshowIndex = {
    north = 1,
    south = 1,
    east = 1,
    west = 1
}

-- Define slideshows for each orientation
local slideshows = {
    north = {
        gfx.image.new("images/forest_bg"),
        gfx.image.new("images/forest_bg"),
        -- Add more slides as needed
    },
    south = {
        gfx.image.new("images/forest_bg"),
        gfx.image.new("images/forest_bg"),
        -- Add more slides as needed
    },
    east = {
        gfx.image.new("images/forest_bg"),
        gfx.image.new("images/forest_bg"),
        -- Add more slides as needed
    },
    west = {
        gfx.image.new("images/entrance_bg"),
        gfx.image.new("images/entrance_bg"),
        -- Add more slides as needed
    }
}

-- Make sure all images are loaded correctly
for _, orientationSlides in pairs(slideshows) do
    for _, image in ipairs(orientationSlides) do
        assert(image)
    end
end

-- Define slide sets for each orientation
local slides = {
    north = {total = 10, current = 1, items = {}, enemies = {}},
    south = {total = 10, current = 1, items = {}, enemies = {}},
    east = {total = 10, current = 1, items = {}, enemies = {}},
    west = {total = 10, current = 1, items = {}, enemies = {}}
}

-- function to handle player input
local function handleInput()
    local selectedDirection = directions[currentDirectionIndex]

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        currentLetterIndex = currentLetterIndex - 1
        if currentLetterIndex < 1 then
            currentLetterIndex = #alphabet
        end
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        currentLetterIndex = currentLetterIndex + 1
        if currentLetterIndex > #alphabet then
            currentLetterIndex = 1
        end
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        currentDirectionIndex = currentDirectionIndex - 1
        if currentDirectionIndex < 1 then
            currentDirectionIndex = #directions
        end
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        currentDirectionIndex = currentDirectionIndex + 1
        if currentDirectionIndex > #directions then
            currentDirectionIndex = 1
        end
    elseif playdate.buttonJustPressed(playdate.kButtonA) and isPopupVisible then
        if selectedDirection and current_room[selectedDirection] then
            current_room = rooms[current_room[selectedDirection]]
            errorMessage = nil -- Clear the error message when a valid direction is chosen
        else
            errorMessage = "You cannot go in that direction"
            errorTimer = 3 -- Start the error timer
        end
        -- Hide the pop-up and clear the current input
        isPopupVisible = false
        currentInput = ""
    end
end

-- function to handle crank input
local function handleCrankInput()
    if not isPopupVisible and player.orientation and current_room[player.orientation] then
        current_room = rooms[current_room[player.orientation]]
        errorMessage = nil -- Clear the error message when a valid direction is chosen
    end
end

-- Function to draw the map
local function drawMap()
    local mapCenterX, mapCenterY = 200, 120 -- Center of the screen
    local roomSize = 20 -- Size of the room representation
    local roomDistance = 40 -- Distance between rooms

    -- Draw the entrance room
    gfx.fillRect(mapCenterX - roomSize/2, mapCenterY - roomSize/2, roomSize, roomSize)

    -- Draw the north room (treasure_room)
    gfx.fillRect(mapCenterX - roomSize/2, mapCenterY - roomDistance - roomSize/2, roomSize, roomSize)

    -- Draw the south room (parking_lot)
    gfx.fillRect(mapCenterX - roomSize/2, mapCenterY + roomDistance - roomSize/2, roomSize, roomSize)

    -- Draw the east room (monster_room)
    gfx.fillRect(mapCenterX + roomDistance - roomSize/2, mapCenterY - roomSize/2, roomSize, roomSize)

    -- Draw the west room (back_room)
    gfx.fillRect(mapCenterX - roomDistance - roomSize/2, mapCenterY - roomSize/2, roomSize, roomSize)

    -- Highlight the current room
    local highlightOffset = 5
    if current_room == rooms.entrance then
        gfx.drawRect(mapCenterX - roomSize/2 - highlightOffset, mapCenterY - roomSize/2 - highlightOffset, roomSize + 2*highlightOffset, roomSize + 2*highlightOffset)
    elseif current_room == rooms.treasure_room then
        gfx.drawRect(mapCenterX - roomSize/2 - highlightOffset, mapCenterY - roomDistance - roomSize/2 - highlightOffset, roomSize + 2*highlightOffset, roomSize + 2*highlightOffset)
    elseif current_room == rooms.parking_lot then
        gfx.drawRect(mapCenterX - roomSize/2 - highlightOffset, mapCenterY + roomDistance - roomSize/2 - highlightOffset, roomSize + 2*highlightOffset, roomSize + 2*highlightOffset)
    elseif current_room == rooms.monster_room then
        gfx.drawRect(mapCenterX + roomDistance - roomSize/2 - highlightOffset, mapCenterY - roomSize/2 - highlightOffset, roomSize + 2*highlightOffset, roomSize + 2*highlightOffset)
    elseif current_room == rooms.back_room then
        gfx.drawRect(mapCenterX - roomDistance - roomSize/2 - highlightOffset, mapCenterY - roomSize/2 - highlightOffset, roomSize + 2*highlightOffset, roomSize + 2*highlightOffset)
    end
end

local function drawWrappedText(text, y, maxWidth, lineHeight)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {""}
    local currentLine = 1
    for i, word in ipairs(words) do
        local linePlusWord = lines[currentLine] .. (lines[currentLine] == "" and "" or " ") .. word
        local lineWidth = gfx.getTextSize(linePlusWord)
        if lineWidth < maxWidth then
            lines[currentLine] = linePlusWord
        else
            currentLine = currentLine + 1
            lines[currentLine] = word
        end
    end

    -- Calculate the starting y-coordinate based on the number of lines and lineHeight
    local totalHeight = #lines * lineHeight
    local startY = y - totalHeight / 2

    -- Draw each line centered
    for i, line in ipairs(lines) do
        local lineWidth = gfx.getTextSize(line)
        local startX = (maxWidth - lineWidth) / 2
        gfx.drawText(line, startX, startY + (i - 1) * lineHeight)
    end
end

function generateItemsAndEnemies(slideSet)
    -- Generate a random number of items and enemies for each slide
    local numItems = math.random(10)
    local numEnemies = math.random(10)

    -- Generate the items and enemies
    for i = 1, numItems do
        table.insert(slideSet.items, generateItem())
    end
    for i = 1, numEnemies do
        table.insert(slideSet.enemies, generateEnemy())
    end
end


-- Function to get accelerometer data
local function getAccelerometerData()
    if playdate.readAccelerometer then
        return playdate.readAccelerometer()
    else
        return 0, 0, 0 -- Return default values if readAccelerometer is not available
    end
end


-- New function to get direction index based on orientation
local function getDirectionIndexFromOrientation(orientation)
    for i, direction in ipairs(directions) do
        if orientation == direction then
            return i
        end
    end
    return 1  -- Default to the first direction if not found
end



-- Game loop function
function playdate.update()
    if game.showTitleScreen then
        gfx.sprite.update()
        gfx.clear()
        entrance_bg_image:draw(0, 0) -- Draw the forest background

        -- Define the text box dimensions and position
        local textBoxWidth = 150
        local textBoxHeight = 30
        local textBoxX = (400 - textBoxWidth) / 2
        local textBoxY = 240 - textBoxHeight - 10 -- 10 pixels from the bottom

        -- Draw the text box
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(textBoxX, textBoxY, textBoxWidth, textBoxHeight)

        -- Draw the "Press A to start" text centered in the text box
        local text = "Press A to start"
        local textWidth, textHeight = gfx.getTextSize(text)
        local textX = textBoxX + (textBoxWidth - textWidth) / 2
        local textY = textBoxY + (textBoxHeight - textHeight) / 2
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText(text, textX, textY)

        -- Play the title screen song if it's not already playing
        if not titleScreenSong:isPlaying() then
            titleScreenSong:play() -- Play the song
        end

        -- Check for button presses to play sound effect
        if pd.buttonJustPressed(pd.kButtonA) then
            buttonPressSound:play() -- Play the button press sound effect
        end

        if pd.buttonJustPressed(pd.kButtonA) then
            game.showTitleScreen = false -- Hide title screen
            titleScreenSong:stop() -- Stop the title screen song
            -- (Initialize the main game state here)
        end

        -- Check if there is an error message to display
        if errorMessage then
            -- Draw the error message
            gfx.setColor(gfx.kColorRed) -- Set the text color to red
            gfx.drawText(errorMessage, 10, 10) -- Draw the text at position (10, 10)

            -- Decrease the error timer
            errorTimer = errorTimer - 1

            -- If the error timer has reached 0, clear the error message
            if errorTimer <= 0 then
                errorMessage = nil
            end
        end
    else
        gfx.sprite.update() -- Clear the screen before drawing new text
        gfx.clear()

        -- Check if the map should be displayed
        if game.showMap then
            drawMap()

            -- If the map button is pressed while the map is open

        if playdate.buttonJustPressed(playdate.kButtonMap) then
            game.showMap = false
        end
    else
        -- Draw the description of the current room with word wrapping and center alignment
        local roomDescription = current_room.description
        local screenWidth = 400
        local screenHeight = 240
        drawWrappedText(roomDescription, screenHeight / 2, screenWidth, 12)

        -- If the current room is the treasure room or the monster room, the game is over
        if current_room == rooms.treasure_room or current_room == rooms.monster_room or current_room == rooms.back_room then
            return
        end
        
        -- Center the question text at the top of the screen
        local questionText = "Where to? Press B to select and A to choose!"
        gfx.drawTextAligned(questionText, screenWidth / 2, 10, kTextAlignment.center)

        -- Check if the B button is pressed
        if playdate.buttonJustPressed(playdate.kButtonB) then
            -- Toggle the visibility of the pop-up
            isPopupVisible = not isPopupVisible

            -- Reset the current input
            currentInput = ""
        end

        -- If the pop-up is visible, handle input
        if isPopupVisible then
            handleInput()
            handleCrankInput()

            -- Draw the current slide based on the player's orientation
            local orientation = player.orientation
            local slideshow = slideshows[orientation]
            local index = slideshowIndex[orientation]
            local currentSlide = slideshow[index]
            currentSlide:draw(0, 0)

        end

        local crankAngle = getCrankAngle()
        local delta = crankAngle - lastCrankAngle
        local x, y, z = getAccelerometerData()

        -- Determine the orientation based on accelerometer data
        local orientation
        if x and y then
            if x > 0.5 then
                orientation = "east"
            elseif x < -0.5 then
                orientation = "west"
            elseif y > 0.5 then
                orientation = "south"
            elseif y < -0.5 then
                orientation = "north"
            else
                orientation = "none"
            end

            -- Show popup with the current orientation using drawText
            gfx.drawText(orientation, 10, 10)
            -- Update the popup direction based on the accelerometer
            currentDirectionIndex = getDirectionIndexFromOrientation(orientation)
        else
            gfx.drawText("No Accelerometer Data.", 120, 190)  -- Use drawText for error message
        end
    
        -- Only allow crank to change slides if in a valid orientation
        if orientation ~= "none" then
            local slideSet = slides[orientation]
            if delta > 10 and slideSet.current < slideSet.total then
                -- Advance to the next slide
                slideSet.current = slideSet.current + 1
            elseif delta < -10 and slideSet.current > 1 then
                -- Go back to the previous slide
                slideSet.current = slideSet.current - 1
            end
        end
    
        lastCrankAngle = crankAngle
    
        

        -- Draw the pop-up text box at the bottom of the screen
        if isPopupVisible then
            -- Set the dither pattern
            if ditherPattern == nil then
                ditherPattern = 12345
            end
            gfx.setDitherPattern(ditherPattern)

            -- Draw the text box background
            local textBoxWidth = 100
            local textBoxHeight = 20
            local textBoxX = (screenWidth - textBoxWidth) / 2
            local textBoxY = screenHeight - textBoxHeight - 10 -- 10 pixels from the bottom
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(textBoxX, textBoxY, textBoxWidth, textBoxHeight)

            -- Draw the text box border
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(textBoxX, textBoxY, textBoxWidth, textBoxHeight)

            -- Draw the selected letter or direction centered in the text box
            local selectedText = isPopupVisible and directions[currentDirectionIndex] or alphabet:sub(currentLetterIndex, currentLetterIndex)
            local textWidth, textHeight = gfx.getTextSize(selectedText)
            gfx.drawText(selectedText, textBoxX + (textBoxWidth - textWidth) / 2, textBoxY + (textBoxHeight - textHeight) / 2)
        end
    end
end

    -- Toggle map display when the Down button is pressed
    if playdate.buttonJustPressed(playdate.kButtonDown) then
        game.showMap = not game.showMap
    end
end

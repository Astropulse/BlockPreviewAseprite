function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	str = str:gsub("\\","/")
	return str:match("(.*/)") or "."
end

-- Initialize variables required for functions.
local path = script_path()

local cube = {128, 128, 128}

local blockPreview = false

local pitch = 45
local roll = 30

local spin = 0
local scale = 1

local blockPreviewDialog = Dialog("Block Preview")

function math.round(number)
	return math.floor(number + 0.5)
end

function rotate3D(block, pitch, yaw, roll)
    for i,point in ipairs(block) do
        local x = point[1]
        local y = point[2]
        local z = point[3]

        local cosa = math.cos(yaw)
        local sina = math.sin(yaw)
        local cosb = math.cos(pitch)
        local sinb = math.sin(pitch)
        local cosc = math.cos(roll)
        local sinc = math.sin(roll)

        local Axx = cosa*cosb
        local Axy = cosa*sinb*sinc - sina*cosc
        local Axz = cosa*sinb*cosc + sina*sinc

        local Ayx = sina*cosb
        local Ayy = sina*sinb*sinc + cosa*cosc
        local Ayz = sina*sinb*cosc - cosa*sinc
        
        local Azx = sinb * -1
        local Azy = cosb*sinc
        local Azz = cosb*cosc

        block[i][1] = Axx*x + Axy*y + Axz*z
        block[i][2] = Ayx*x + Ayy*y + Ayz*z
        block[i][3] = Azx*x + Azy*y + Azz*z
    end
end

function makeCube(x, y, z)
    x = x*scale
    y = y*scale
    z = z*scale
    return {{(x/2)*-1,(y/2)*-1,(z/2)*-1},
            {(x/2)*1,(y/2)*-1,(z/2)*-1},
            {(x/2)*1,(y/2)*1,(z/2)*-1},
            {(x/2)*-1,(y/2)*1,(z/2)*-1},
            {(x/2)*-1,(y/2)*-1,(z/2)*1},
            {(x/2)*1,(y/2)*-1,(z/2)*1},
            {(x/2)*1,(y/2)*1,(z/2)*1},
            {(x/2)*-1,(y/2)*1,(z/2)*1}}
end

local block = makeCube(cube[1], cube[2], cube[3])

function calcPixel(points, canvas, x, y)
    return {(points[1][1] + (((points[2][1] - points[1][1]) / canvas.width) * x) + ((points[3][1] - points[1][1]) / canvas.height) * y), (points[1][2] + (((points[3][2] - points[1][2]) / canvas.height) * y) + ((points[2][2] - points[1][2]) / canvas.width) * x)}
end

function init(plugin)
    
    plugin:newCommand{id = "block",
    title = "Block Preview",
    group = "view_canvas_helpers",
    onenabled = function()
        return app.activeCel ~= nil and app.activeSprite.width < 64 and app.activeSprite.height < 64
    end,
    onclick = function()

        blockPreview = true

        local connect_points = {{{1,2},{2,3},{3,4},{4,1}},
                                {{5,1},{1,4},{4,8},{8,5}},
                                {{4,3},{3,7},{7,8},{8,4}},
                                {{6,5},{5,8},{8,7},{7,6}},
                                {{5,6},{6,2},{2,1},{1,5}},
                                {{2,6},{6,7},{7,3},{3,2}}}
        
        local colors = {Color(255, 0, 0, 64), Color(0, 255, 0, 64), Color(0, 0, 255, 64), Color(255, 255, 0, 64), Color(0, 255, 255, 64), Color(255, 0, 255, 64)}

        block = makeCube(cube[1], cube[2], cube[3])

        local drag = 0

        spin = 0
        scale = 1
        pitch = 45
        roll = 30

        rotate3D(block, pitch*math.pi/180, 0, 0)
        rotate3D(block, 0, 0, roll*math.pi/180)

        blockPreviewDialog = Dialog("Block Preview")
        blockPreviewDialog
        :canvas{
            id="canvas",
            width=256,
            height=256,
            onpaint=function(ev)
                if app.activeSprite.width < 64 and app.activeSprite.height < 64 then
                    local ctx = ev.context

                    local outline = blockPreviewDialog.data.outline

                    local cx = ctx.width/2
                    local cy = ctx.height/2

                    ctx.antialias = blockPreviewDialog.data.antialias

                    ctx.color = blockPreviewDialog.data.backgroundColor
                    ctx:fillRect(Rectangle(0, 0, ctx.width, ctx.height))
                    local remap = {}
                    local recolors = {}

                    local numbers = {"1", "2", "3", "4", "5", "6"}

                    local numCoords = {}
                    local numString = {}

                    -- Cheap backface culling + face information + scaling
                    for i, face in ipairs(connect_points) do

                        local x = 0.0
                        local y = 0.0
                        local z = 0.0
                        for n, edges in ipairs(face) do
                            x = x + block[edges[1]][1]
                            y = y + block[edges[1]][2]
                            z = z + block[edges[1]][3]
                        end
                        x = x/#face
                        y = y/#face
                        z = z/#face

                        if z <0 then
                            remap[#remap+1] = face
                            recolors[#recolors+1] = colors[i]

                            numCoords[#numCoords+1] = {x, y, z}
                            numString[#numString+1] = numbers[i]
                        end

                        
                    end

                    -- Outline script
                    if outline > 0 then
                        for i, face in ipairs(remap) do
                            ctx:beginPath()
                            ctx.strokeWidth = outline
                            for n, edges in ipairs(face) do
                                ctx:moveTo(block[edges[1]][1]+cx,block[edges[1]][2]+cy)
                                ctx:lineTo(block[edges[2]][1]+cx,block[edges[2]][2]+cy)
                            end
                            ctx:stroke()
                        end
                        ctx:beginPath()
                        for i, point in ipairs(block) do
                            ctx:roundedRect(Rectangle((point[1]-(outline/2)+0.5)+cx, (point[2]-(outline/2)+0.5)+cy, outline, outline), outline, outline) 
                        end
                        ctx:fill()
                    end
                    
                    local canvas = Image(app.activeSprite.width, app.activeSprite.height)
                    canvas:drawSprite(app.activeSprite, app.activeFrame) 
                    ctx.strokeWidth = 0
                    for pixel in canvas:pixels() do
                        ctx.color = Color(app.pixelColor.rgbaR(pixel()),app.pixelColor.rgbaG(pixel()),app.pixelColor.rgbaB(pixel()),app.pixelColor.rgbaA(pixel()))
                        for i, face in ipairs(remap) do
                            ctx:beginPath()

                            local pixelXY = {}
                            local points = {block[face[1][1]],block[face[2][1]],block[face[4][1]]}

                            pixelXY = calcPixel(points, canvas, pixel.x, pixel.y)
                            ctx:moveTo(pixelXY[1] + cx, pixelXY[2] + cy)
                            pixelXY = calcPixel(points, canvas, pixel.x+1, pixel.y)
                            ctx:lineTo(pixelXY[1] + cx, pixelXY[2] + cy)
                            pixelXY = calcPixel(points, canvas, pixel.x+1, pixel.y+1)
                            ctx:lineTo(pixelXY[1] + cx, pixelXY[2] + cy)
                            pixelXY = calcPixel(points, canvas, pixel.x, pixel.y+1)
                            ctx:lineTo(pixelXY[1] + cx, pixelXY[2] + cy)

                            ctx:closePath()
                            ctx:fill()
                            if blockPreviewDialog.data.antialias then
                                ctx:stroke()
                            end
                        end
                    end



                    -- Debug view
                    if blockPreviewDialog.data.debug then
                        
                        -- Draw colored block faces
                        for i, face in ipairs(remap) do
                            ctx:beginPath()
                            ctx.strokeWidth = 0
                            ctx.color = recolors[i]
                            ctx:moveTo(block[face[1][1]][1]+cx,block[face[1][1]][2]+cy)
                            for n, edges in ipairs(face) do
                                ctx:lineTo(block[edges[1]][1]+cx,block[edges[1]][2]+cy)
                                ctx:lineTo(block[edges[2]][1]+cx,block[edges[2]][2]+cy)
                            end
                            ctx:closePath()
                            ctx:fill()
                        end
                        
                        -- Draw debug text
                        for i, face in ipairs(remap) do
                            ctx:beginPath()
                            ctx.color = Color(recolors[i].red, recolors[i].green, recolors[i].blue, math.min(255, math.max(0,numCoords[i][3]*-(1024/((cube[1]+cube[2]+cube[3])/3))-5)/scale))
                            ctx:fillText(numString[i], (numCoords[i][1]+cx)-3, (numCoords[i][2]+cy)-5)
                            local coords = tostring(math.round(numCoords[i][1]))..", "..tostring(math.round(numCoords[i][2]))..", "..tostring(math.round(numCoords[i][3]))
                            ctx:fillText(coords, (numCoords[i][1]+cx)-ctx:measureText(coords).width/2, (numCoords[i][2]+cy)+5)
                        end
                        ctx.color = Color(255, 0, 0, 255)
                        if blockPreviewDialog.data.debug then
                            ctx:fillText("X Axis: "..roll, 10, 10)
                            ctx:fillText("Y Axis: "..math.round(pitch), 10, 20)
                            ctx:fillText("Zoom: "..scale, 10, 30)
                        end
                    end
                end
            end,
            onmousedown = function(ev)
                drag = 1
                spin = 0
                px = ev.x
                py = ev.y
            end,
            onmouseup = function(ev)
                drag = 0
                spin = blockPreviewDialog.data.spin
            end,
            onwheel = function(ev)
                scale = math.max(0.1, scale-(ev.deltaY/10))
                block = makeCube(cube[1], cube[2], cube[3])
                rotate3D(block, pitch*math.pi/180, 0, 0)
                rotate3D(block, 0, 0, roll*math.pi/180)
                blockPreviewDialog:repaint()
            end,
            onmousemove = function(ev)
                if drag == 1 then
                    roll = (roll+(ev.y-py))%360
                    pitch = (pitch+((px-ev.x)*math.cos(roll*math.pi/180)))%360
                    block = makeCube(cube[1], cube[2], cube[3])
                    rotate3D(block, pitch*math.pi/180, 0, 0)
                    rotate3D(block, 0, 0, roll*math.pi/180)
                    blockPreviewDialog:repaint()
                    px = ev.x
                    py = ev.y 
                end
            end
        }
        :color{
            id = "outlineColor",
            color = app.fgColor,
            onchange = function()
                blockPreviewDialog:repaint()
            end,
            visible = false
        }
        :color{
            id = "backgroundColor",
            color = app.bgColor,
            onchange = function()
                blockPreviewDialog:repaint()
            end
        }
        :slider{
            id = "outline",
            min = 0,
            max = 10,
            value = 0,
            onchange = function()
                blockPreviewDialog:repaint()
            end,
            visible = false
        }
        :newrow()
        :slider{
            id = "spin",
            min = -10,
            max = 10,
            value = 0,
            onchange = function()
                spin = blockPreviewDialog.data.spin
                blockPreviewDialog:repaint()
            end
        }
        :check{
            id = "antialias",
            text = "Antialias",
            selected = false,
            onclick = function()
                blockPreviewDialog:repaint()
            end
        }
        :check{
            id = "debug",
            text = "Advanced view",
            selected = false,
            onclick = function()
                blockPreviewDialog:repaint()
                blockPreviewDialog:modify{id = "x", visible = blockPreviewDialog.data.debug}
                blockPreviewDialog:modify{id = "y", visible = blockPreviewDialog.data.debug}
                blockPreviewDialog:modify{id = "z", visible = blockPreviewDialog.data.debug}
            end
        }
        :slider{
            id = "x",
            min = 16,
            max = 256,
            value = cube[1],
            onchange = function()
                cube[1] = blockPreviewDialog.data.x
                block = makeCube(cube[1], cube[2], cube[3])
                rotate3D(block, pitch*math.pi/180, 0, 0)
                rotate3D(block, 0, 0, roll*math.pi/180)
                blockPreviewDialog:repaint()
            end,
            visible = false
        }
        :slider{
            id = "y",
            min = 16,
            max = 256,
            value = cube[2],
            onchange = function()
                cube[2] = blockPreviewDialog.data.y
                block = makeCube(cube[1], cube[2], cube[3])
                rotate3D(block, pitch*math.pi/180, 0, 0)
                rotate3D(block, 0, 0, roll*math.pi/180)
                blockPreviewDialog:repaint()
            end,
            visible = false
        }
        :slider{
            id = "z",
            min = 16,
            max = 256,
            value = cube[3],
            onchange = function()
                cube[3] = blockPreviewDialog.data.z
                block = makeCube(cube[1], cube[2], cube[3])
                rotate3D(block, pitch*math.pi/180, 0, 0)
                rotate3D(block, 0, 0, roll*math.pi/180)
                blockPreviewDialog:repaint()
            end,
            visible = false
        }
        :button{
            text = "Reset",
            onclick = function()
                pitch = 45
                roll = 30
                scale = 1
                cube = {128, 128, 128}
                block = makeCube(cube[1], cube[2], cube[3])
                rotate3D(block, pitch*math.pi/180, 0, 0)
                rotate3D(block, 0, 0, roll*math.pi/180)
                blockPreviewDialog:repaint()
                blockPreviewDialog:modify{id = "x", value = cube[1]}
                blockPreviewDialog:modify{id = "y", value = cube[2]}
                blockPreviewDialog:modify{id = "z", value = cube[3]}
            end
        }
        :button{text = "Cancel"}
        blockPreviewDialog:show{wait = false}
    end
    
}

end

Timer{
    interval=0.01,
    ontick=function()
        if blockPreview then
            pitch = (pitch-(spin/8))%360
            block = makeCube(cube[1],cube[2],cube[3])
            rotate3D(block, pitch*math.pi/180, 0, 0)
            rotate3D(block, 0, 0, roll*math.pi/180)
            blockPreviewDialog:repaint()
        end
    end
}:start()
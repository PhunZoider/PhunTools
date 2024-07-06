function PhunTools:boxToSquares(x1, x2, y1, y2)
    local area = {}

    for i = x1, x2 do
        for j = y1, y2 do
            table.insert(area, getSquare(i, j, 0))
        end
    end

    return area

end

function PhunTools:xyzToSquares(xyzs)
    local squares = ArrayList.new();
    for _, xyz in ipairs(xyzs or {}) do
        local square = getSquare(xyz.x, xyz.y, xyz.z or 0)
        if square then
            squares:add(square);
        end
    end
    return squares;
end

function PhunTools:removeHighlightedArea(xyzs)
    local squares = self:xyzToSquares(xyzs);
    if squares:size() > 0 then
        self:removeHighlightedSquares(squares);
    end
end

function PhunTools:removeHighlightedSquares(squares)
    for _, square in ipairs(squares) do
        local objects = square:getObjects();
        for j = 0, objects:size() - 1 do
            local obj = objects:get(j);
            obj:setHighlighted(false, false);
        end
    end
end

function PhunTools:highlightArea(xyzs, color)

    local squares = self:xyzToSquares(xyzs);
    if squares:size() > 0 then
        self:highlightSquares(squares, color);
    end
end

function PhunTools:highlightSquares(squares, color)
    local c = color or {
        a = 0.5,
        r = 1,
        g = 0,
        b = 0
    };
    for _, square in ipairs(squares) do
        local objects = square:getObjects();
        for j = 0, objects:size() - 1 do
            local obj = objects:get(j);
            obj:setHighlighted(true, false);
            obj:setHighlightColor(c.r, c.g, c.b, c.a);
        end
    end
end

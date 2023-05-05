local transform = {}

function transform.translate(x, y, ...)
    local p = {...}
    local pairity = true
    for i = 1, #p do
        p[i] = p[i] + (pairity and x or y)
        pairity = not pairity
    end
    return unpack(p)
end

function transform.scale(s, ...)
    local p = {...}
    for i = 1, #p do
        p[i] = p[i] * s
    end
    return unpack(p)
end

function transform.stretch(x, y, ...)
    local p = {...}
    local pairity = true
    for i = 1, #p do
        p[i] = p[i] * (pairity and x or y)
        pairity = not pairity
    end
    return unpack(p)
end

return transform
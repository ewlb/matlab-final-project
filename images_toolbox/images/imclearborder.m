%

function out = imclearborder(in,conn,options)
    arguments
        % The slightly unusual construction of this arguments block
        % supports both the original syntax, where conn is an optional
        % positional argument, as well as the Connectivity named argument,
        % which was added to the syntax later. The combination of defaults
        % for conn and options.Connectivity was chosen to enable either
        % syntax with the same default value.

        in {mustBeNumericOrLogical, mustBeReal, mustBeNonsparse}
        conn {images.internal.mustBeConnectivity} = ...
            ones(repmat(3,1,ndims(in)))
        options.Borders {images.internal.mustBeBorders} = true(ndims(in),2)
        options.Connectivity {images.internal.mustBeConnectivity} = ...
            conn
    end

    % Algorithm: form a border image using IMKEEPBORDER and then subtract
    % that from the original image, using either arithmetic subtraction or
    % a logical AND NOT operation.
    
    objects = imkeepborder(in, Borders = options.Borders, ...
        Connectivity = options.Connectivity);

    if islogical(in)
        out = in & ~objects;
    else
        out = in - objects;
    end
end

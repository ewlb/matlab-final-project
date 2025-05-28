classdef CategoricalConverter
% CATEGORICALCONVERTER - Class to handle categorical2numeric and
% numeric2categorical conversions.

%  Copyright 2019-2020 The MathWorks, Inc.
    
    properties(Access = private)
       % Num2CatLUT - LUT for numeric to categorical conversion 
       Num2CatLUT
       
       % Categories - Cell array of category names to be used for conversion 
       Categories
       
       % Valueset - Numeric values corresponding to the categories.
       ValueSet
    end
    
    methods
        function obj = CategoricalConverter(valueSet, categories)
            obj.Categories = categories;
            obj.ValueSet = valueSet;
            obj.cacheNum2CategoricalLUT();
        end
        
        function out = numeric2Categorical(obj, numericIn)
            % NUMERIC2CATEGORICAL converts numeric array to a categorical.
            % The conversion is performed using the the cached categories.
            %
            % in            - numeric input to be converted
            % out           - converted categorical array
           
            assert(isnumeric(numericIn), 'Error. Input is expected to be numeric');
            if(~isempty(obj.Num2CatLUT))    
                % Use LUT for conversion.
                
                % Shift values by 1, to account for the '0' label. The LUTCache
                % already includes this shift.
                out = obj.Num2CatLUT(numericIn+1);    
            else
                out = categorical(numericIn, 1:numel(obj.Categories),...
                                                     obj.Categories);
            
            end
        end
        
        function out = categorical2numeric(obj, categoricalIn)
            % CATEGORICAL2NUMERIC converts categorical array to a numeric array with
            % datatype dependent on number of categories.
            %
            % in            - categorical input to be converted
            % out           - converted numeric array
            
            assert(iscategorical(categoricalIn), 'Error. Input is expected to be categorical');
            numCategories = numel(obj.Categories);

            if(numCategories <= 2^8)
                out = uint8(categoricalIn); 
            elseif(numCategories > 2^8) && (numCategories <= 2^16)
                out = uint16(categoricalIn); 
            elseif(numCategories > 2^16) && (numCategories <= 2^32)
                out = uint32(categoricalIn); 
            else
                out = uint64(categoricalIn); 
            end
        end
        
    end
    
    methods (Access = private)
        function obj = cacheNum2CategoricalLUT(obj)
            % Create a LUT to convert a numeric array into categorical. The
            % categories are shifted by 1 to accomodate '0' label.
            %
            % categories - Cell array of category/class names. The max allowed length
            %              of categories is 256.
            
            if(numel(obj.Categories) < 256)
                % Shift value set for labels by 1, to account for '0' label,
                % corrsponding to '<undefined>' pixels.
                numericLUT = 1:256+1;
                obj.Num2CatLUT = categorical(numericLUT, 2:numel(obj.Categories)+1, obj.Categories);
            else
                obj.Num2CatLUT = [];
            end
        
        end
    end
end
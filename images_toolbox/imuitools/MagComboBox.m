classdef MagComboBox < matlab.ui.componentcontainer.ComponentContainer

    
    properties (Dependent = true)

        MagnificationValue

    end

    properties (Access = private)

        MagValue 
        

    end

    properties(SetAccess = private,UsedInUpdate = false)

        isFitMag = false % Fit Magnification

    end
    events (HasCallbackProperty, NotifyAccess = protected)

        ValueChanged 

    end

    
    properties (Access = private, Transient, NonCopyable)

        DropDown matlab.ui.control.DropDown
        GridLayout matlab.ui.container.GridLayout

    end
    
    methods

        function set.MagnificationValue(obj,val)
            obj.MagValue = val;
        end

        function value = get.MagnificationValue(obj)
            value = obj.MagValue;
        end

    end

    methods (Access=protected)

        function setup(obj)

             % Layout
            obj.GridLayout = uigridlayout(obj, ...
                'RowHeight',{'Fit'},'ColumnWidth',{'Fit'},...
                'Padding',0,'RowSpacing',0,'ColumnSpacing',0);

            obj.DropDown = uidropdown(obj.GridLayout,"Editable","on","ValueChangedFcn",@(o,e) obj.handleNewValue(o,e),...
                "Items",{getString(message('images:imtoolUIString:magnifyFitToWindow')),...
                '33%','50%','67%','100%','200%','400%'});
          
        end
        
        function update(obj)

            % Update view
            if(isnumeric(obj.MagnificationValue))
            percentMag = [num2str(round(obj.MagnificationValue * 100)) '%'];
            obj.DropDown.Value = percentMag;
            end
            
        end
    end
       
    methods (Access=private)
        
        function handleNewValue(obj,src,event)
            
            magstr = src.Value;

            % Special case: Fit To Window
            if strcmp(magstr,getString(message('images:imtoolUIString:magnifyFitToWindow')))
                obj.isFitMag = true;
            else
                obj.isFitMag = false;
            end

            if obj.isFitMag
                notify(obj,'ValueChanged');
                % Return from here as magnification value is not known and
                % depends on scroll panel API. 
                % Client will set the magnification
                return

            end

            % Parse string Remove "%"
            if(strcmp(magstr(end),'%'))
               magstr = magstr(1:end-1);
            end

            magNum = str2double(magstr);

            % Check for non-numeric items before assigning
            if(~isnan(magNum))
                obj.MagValue = magNum/100;
            else
                % If the user has entered a non-numeric value, return to
                % previous magnification               
                obj.DropDown.Value = event.PreviousValue;
            end

            notify(obj,'ValueChanged');
        end

         
    end
end

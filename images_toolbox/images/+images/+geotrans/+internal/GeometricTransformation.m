classdef GeometricTransformation%#codegen
    %GeometricTransformation Base class for geometric transformations
    %
    %   The GeometricTransformation class formalizes
    %   the required interface for geometric transformations in the image
    %   processing toolbox. This class is an abstract base class.
    %
    %   GeometricTransformation properties:
    %      Dimensionality - Dimensionality of geometric transformation
    %
    %   GeometricTransformation methods:
    %      outputLimits - Find output spatial limits given input spatial limits
    %      transformPointsInverse (ABSTRACT) - Apply inverse 2-D geometric transformation to points
    %
    %   See also affine3d, projective2d, geometricTransform2D, geometricTransform3D
    
    % Copyright 2012-2023 The MathWorks, Inc.
    
    %#ok<*EMCA>
    
    properties (Abstract,Hidden)
        IsBidirectional
    end

    methods (Abstract = true)
        
        % We apply all geometric transforms using reverse mapping. The
        % minimum requirement of all geometric transforms is that they
        % define transformPointsInverse.
        varargout = transformPointsInverse(varargin);
        
    end
    
    methods
        
        function varargout = outputLimits(self,xLimitsIn,yLimitsIn,zLimitsIn)
            %outputLimits Find output limits of geometric transformation
            %
            %   If Dimensionality == 2
            %
            %   [xLimitsOut,yLimitsOut] = outputLimits(tform,xLimitsIn,yLimitsIn) estimates the
            %   output spatial limits corresponding to a given geometric
            %   transformation and a set of input spatial limits.
            %
            %   If Dimensionality == 3
            %
            %   [xLimitsOut,yLimitsOut,zLimitsOut] = outputLimits(tform,xLimitsIn,yLimitsIn,zLimitsIn) estimates the
            %   output spatial limits corresponding to a given geometric
            %   transformation and a set of input spatial limits.
            
            coder.inline('always');
            
            if (self.Dimensionality == 2)
                
                narginchk(3,3)
                
                validateattributes(xLimitsIn,{'double'},{'size',[1 2],'finite','nonnan','nonempty'},'images.geotrans.internal.GeometricTransformation.outputLimits','xLimitsIn');
                validateattributes(yLimitsIn,{'double'},{'size',[1 2],'finite','nonnan','nonempty'},'images.geotrans.internal.GeometricTransformation.outputLimits','yLimitsIn');
                
                u = [xLimitsIn(1), mean(xLimitsIn), xLimitsIn(2)];
                v = [yLimitsIn(1), mean(yLimitsIn), yLimitsIn(2)];
                
                % Form grid of boundary points and internal points used by
                % findbounds algorithm.
                [U,V] = meshgrid(u,v);

                if isa(self, 'images.geotrans.internal.MatrixTransformation')
                    [X,Y] = transformPointsForward(self,U,V);
                else
                    if self.IsBidirectional
                        % Transform gridded points forward
                        [X,Y] = transformPointsForward(self,U,V);

                    else
                        % If the forward transformation is not defined, use
                        % numeric optimization to estimate the output bounds
                        [X,Y] = estimateForwardMapping(self,U,V);
                    end
                end
                
                % XLimitsOut/YLimitsOut are formed from min and max of transformed points.
                varargout{1} = [min(X(:)), max(X(:))];
                varargout{2} = [min(Y(:)), max(Y(:))];
                
            else %(self.Dimensionality == 3)
                
                narginchk(4,4)
                
                validateattributes(xLimitsIn,{'double'},{'size',[1 2],'finite','nonnan','nonempty'},'images.geotrans.internal.GeometricTransformation.outputLimits','xLimitsIn');
                validateattributes(yLimitsIn,{'double'},{'size',[1 2],'finite','nonnan','nonempty'},'images.geotrans.internal.GeometricTransformation.outputLimits','yLimitsIn');
                validateattributes(zLimitsIn,{'double'},{'size',[1 2],'finite','nonnan','nonempty'},'images.geotrans.internal.GeometricTransformation.outputLimits','zLimitsIn');
                
                u = [xLimitsIn(1), mean(xLimitsIn), xLimitsIn(2)];
                v = [yLimitsIn(1), mean(yLimitsIn), yLimitsIn(2)];
                w = [zLimitsIn(1), mean(zLimitsIn), zLimitsIn(2)];
                
                % Form grid of boundary points and internal points used by
                % findbounds algorithm.
                [U,V,W] = meshgrid(u,v,w);
                
                if isa(self, 'images.geotrans.internal.MatrixTransformation')
                    [X,Y,Z] = transformPointsForward(self,U,V,W);
                else
                    if self.IsBidirectional
                        % Transform gridded points forward
                        [X,Y,Z] = transformPointsForward(self,U,V,W);
                    else
                        % If the forward transformation is not defined, use
                        % numeric optimization to estimate the output bounds
                        [X,Y,Z] = estimateForwardMapping(self,U,V,W);
                    end
                end
                
                % XLimitsOut/YLimitsOut are formed from min and max of transformed points.
                varargout{1} = [min(X(:)), max(X(:))];
                varargout{2} = [min(Y(:)), max(Y(:))];
                varargout{3} = [min(Z(:)), max(Z(:))];
                
            end
            
        end
        
    end
    
    methods (Access = private)
        
        function varargout = estimateForwardMapping(self,varargin) 
            
            coder.inline('always');
            coder.internal.prefer_const(varargin);
            
            % Turn off textual display during optimization.
            options = optimset('Display','off');
            if (self.Dimensionality == 2)
                narginchk(3,3)
                U = varargin{1};
                V = varargin{2};
                [X,Y] = deal(zeros(size(U)));
                
                for i = 1:numel(U)
                    
                    u0 = [U(i) V(i)];
                    objective_function = @(x,u0, self) norm(u0 - self.transformPointsInverse(x));
                    
                    [x,~,exitflag] = fminsearch(objective_function, u0, options, u0, self);
                    
                    optimizationFailed = exitflag <=0;
                    if optimizationFailed
                        X = U;
                        Y = V;
                        coder.internal.warning('images:geotrans:estimateOutputBoundsFailed');
                        break;
                    else
                        X(i) = x(1);
                        Y(i) = x(2);
                    end
                    
                end
                varargout{1} = X;
                varargout{2} = Y;
                
            else % (self.Dimensionality == 3)
                narginchk(4,4)
                U = varargin{1};
                V = varargin{2};
                W = varargin{3};
                
                [X,Y,Z] = deal(zeros(size(U)));
                
                for i = 1:numel(U)
                    
                    u0 = [U(i) V(i) W(i)];
                    objective_function = @(x,u0, self) norm(u0 - self.transformPointsInverse(x));
                    
                    [x,~,exitflag] = fminsearch(objective_function, u0, options, u0, self);
                    
                    optimizationFailed = exitflag <=0;
                    if optimizationFailed
                        X = U;
                        Y = V;
                        Z = W;
                        coder.internal.warning('images:geotrans:estimateOutputBoundsFailed');
                        break;
                    else
                        X(i) = x(1);
                        Y(i) = x(2);
                        Z(i) = x(3);
                    end
                    
                end
                varargout{1} = X;
                varargout{2} = Y;
                varargout{3} = Z;
            end
            
            
        end
         
    end
    
    properties (Abstract, Constant)
        
        %Dimensionality - Dimensionality of geometric transformation
        %
        %    Dimensionality describes the dimensionality of the geometric
        %    transformation for both input and output points.
        Dimensionality
        
    end
    
    
end


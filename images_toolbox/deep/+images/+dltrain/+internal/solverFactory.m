function solver = solverFactory(opts)

import images.dltrain.internal.*

if isa(opts,'nnet.cnn.TrainingOptionsSGDM')
    solver = SGDMSolver(opts.InitialLearnRate,opts.Momentum);
elseif isa(opts,'nnet.cnn.TrainingOptionsADAM')
    solver = AdamSolver(opts.InitialLearnRate,opts.GradientDecayFactor,...
        opts.SquaredGradientDecayFactor,opts.Epsilon);
elseif isa(opts,'nnet.cnn.TrainingOptionsRMSProp')
    solver = RMSPropSolver(opts.InitialLearnRate,opts.SquaredGradientDecayFactor,...
        opts.Epsilon);
else
   assert(false,'Unsupported solver option'); 
end

end
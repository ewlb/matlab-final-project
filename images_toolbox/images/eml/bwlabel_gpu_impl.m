function [final, components] = bwlabel_gpu_impl(img, mode) %#codegen
    % BWLABEL Label connected components in 2-D binary image.
    % Based on the "Komura Equivalence" Connected component labeling algorithm.
    % Playne, D. P., & Hawick, K. (2018). A new algorithm for parallel connected-component labelling on GPUs. IEEE Transactions on Parallel and Distributed Systems, 29(6), 1217-1230.

    % Copyright 2023 The MathWorks, Inc.
    [rows, cols] = size(img);
    [B, T] = get_launch_config(num_elements=numel(img), work_per_thread=16, threads=1024);
    labels = coder.nullcopy(zeros(size(img), 'int32'));
    mask = coder.nullcopy(false(numel(img), 1));

    % Init phase

    % Each parallel unit is a thread mapped to unique location in 2D grids.
    coder.gpu.kernel(B, T, -1, "_init");
    for col = 1:size(img, 2)
        coder.gpu.kernel;
        for row = 1:size(img, 1)
            if mode == 8 && row > 1 && col > 1 && img(row - 1, col - 1) && img(row, col)
                labels(row, col) = sub2ind(size(labels), row - 1, col - 1);
            elseif col > 1 && img(row, col - 1) && img(row, col)
                labels(row, col) = sub2ind(size(labels), row, col - 1);
            elseif mode == 8 && row < rows && col > 1 && img(row + 1, col - 1) && img(row, col)
                labels(row, col) = sub2ind(size(labels), row + 1, col - 1);
            elseif row > 1 && img(row - 1, col) && img(row, col)
                labels(row, col) = sub2ind(size(labels), row - 1, col);
            elseif img(row, col)
                labels(row, col) = sub2ind(size(labels), row, col);
            else
                labels(row, col) = 0;
            end
        end
    end

    % Analyze phase
    coder.gpu.kernel(B, T, -1, "_analyze");
    for col = 1:size(img, 2)
        coder.gpu.kernel;
        for row = 1:size(img, 1)
            label = labels(row, col);
            if label
                index = int32(sub2ind(size(labels), row, col));
                while label ~= index
                    index = label;
                    label = labels(label);
                end
                labels(row, col) = label;
            end
        end
    end

    % Reduce phase

    % The Reduce phase GAURANTEES that only a TRUE ROOT points to itself, and all other
    % "intermediate" roots (that currently point to itself as of end of Analyze(1) phase),
    % will point to a "higher-ranked" root nearby if exists.
    %
    % The union operation does not gaurantee that all the intermediate roots point to the TRUE ROOT
    % (TRUE ROOT is the member of the tree/connected-component with least linear index).
    % (IOW, doesn't gaurantee complete shallowing/reduction of trees)
    % But it gaurantees that no intermediate root wrongly points to itself.
    % This is important, because the subsequent 2nd pass "compression" aka "analysis" phase will make sure
    % all intermediate roots point to the TRUE ROOT, and all trees are completely shallowed.
    coder.gpu.kernel(B, T, -1, "_reduce");
    for col = 1:size(img, 2)
        coder.gpu.kernel;
        for row = 1:size(img, 1)
            if img(row, col)
                if mode == 8 && row < rows && col > 1 && img(row + 1, col - 1)
                    labels = union(labels, int32(sub2ind(size(labels), row, col)), int32(sub2ind(size(labels), row + 1, col - 1)));
                end
                if row > 1 && img(row - 1, col)
                    labels = union(labels, int32(sub2ind(size(labels), row, col)), int32(sub2ind(size(labels), row - 1, col)));
                end
            end
        end
    end

    % Another Analyze phase (includes mask creation)
    coder.gpu.kernel(B, T, -1, "_analyze2");
    for col = 1:size(img, 2)
        coder.gpu.kernel;
        for row = 1:size(img, 1)
            label = labels(row, col);
            index = int32(sub2ind(size(labels), row, col));
            mask(index) = (label == index);
            if label
                while label ~= index
                    index = label;
                    label = labels(label);
                end
                labels(row, col) = label;
            end
        end
    end

    [final, components] = postprocess(labels, mask, B, T);
end

function [final, components] = postprocess(labels, mask, B, T)
    coder.inline('always');
    coder.gpu.kernelfun;
    final = coder.nullcopy(zeros(size(labels), 'double'));
    [compacted_indices, components] = gpucoder.internal.datacompaction.scan1d(mask);
    components = double(components);

    coder.gpu.kernel(B, T, -1, "_scatter");
    for j = 1:size(labels, 2)
        coder.gpu.kernel;
        for i = 1:size(labels, 1)
            root_loc = labels(i, j);
            if root_loc == 0
                final(i, j) = 0;
                continue;
            else
                val = compacted_indices(root_loc);
                final(i, j) = double(val);
            end
        end
    end
end

function labels = union(labels, a, b)
    % A thread-aware Union operation of the two trees containing nodes a and b.
    % This union operation is aware of the fact that multiple threads can WRITE to `labels()` at the same time.
    % The `atomicMin` operation is gauranteed to be atomic,
    % but any other place can have a dirty write to `labels` and we should take that into consideration.
    % That is why we do `(old == b)` or `(old == a)` to know if `labels(b)` or `labels(a)` is dirty.
    % If it turns out to be dirty, we repeat the (findRoot, atomicMin) steps so as to ensure consistency.

    coder.inline('always');
    done = false;
    while ~done
        a = find_root(labels, a);
        b = find_root(labels, b);
        if a < b
            % check if non-inline does not pass stack var instead of global mem.
            [labels(b), old] = gpucoder.atomicMin(labels(b), a);
            done = (old == b);
            b = old;
        elseif b < a
            [labels(a), old] = gpucoder.atomicMin(labels(a), b);
            done = (old == a);
            a = old;
        else
            done = true;
        end
    end
end

function root = find_root(labels, n)
    % Returns the root of the tree containing the node n.
    coder.inline('always');
    lbl = labels(n);
    while lbl ~= n
        n = lbl;
        lbl = labels(n);
    end
    root = n;
end

function [B, T] = get_launch_config(opts)
    % Returns the number of blocks and threads per block to launch the kernel
    % factoring in the number of elements to process, number of threads per block,
    % and sequential work to be assigned per thread.
    arguments
        opts.num_elements;
        opts.work_per_thread = 16;
        opts.threads = 1024;
    end
    coder.inline('always');
    B = ceil(opts.num_elements/(opts.threads*opts.work_per_thread));
    T = opts.threads;
end
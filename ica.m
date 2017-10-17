% setup variables
L = 50000; % samples per vector
RowsToAnalyze = 4; % rows of the matricies to input to the analysing functions
RowsToFind = 2; % rows to output from the analysing functions (number of signals we are looking for)
ICAType = 'kurtosis'; % Type of ica for function fastICA. 'kurtosis' or 'negentropy'


% constants
f = 44100; % sampling frequency
Ts = 1/f; % sample time

fprintf('Searching for %i signals from the group of %i signals\n', RowsToFind, RowsToAnalyze);

% Load audio files into matrices
s1 = audioread('samples/wave_1.wav')';
s2 = audioread('samples/wave_2.wav')';
s3 = audioread('samples/wave_3.wav')';
s4 = audioread('samples/wave_4.wav')';
S = [s1(1:L);s2(1:L);s3(1:L);s4(1:L)];
S = normalizeAudio(S);

x1 = audioread('samples/mixed_1.wav')';
x2 = audioread('samples/mixed_2.wav')';
x3 = audioread('samples/mixed_3.wav')';
x4 = audioread('samples/mixed_4.wav')';
X = [x1(1:L);x2(1:L);x3(1:L);x4(1:L)];
X = normalizeAudio(X);

% Plot the original signals
plotMatrix(S, 4, RowsToAnalyze, 1, 'Original signal');

% Plot the mixed signals
plotMatrix(X, 4, RowsToAnalyze, 2, 'Mixed signal');

% Do the different types of analysis
Y1 = fastICA(X(1:RowsToAnalyze, :), RowsToFind, ICAType, 0);
Y2 = kICA(X(1:RowsToAnalyze, :), RowsToFind);
Y3 = PCA(X(1:RowsToAnalyze, :), RowsToFind);

% Normalize results to range 0-1
Y1 = normalizeAudio(Y1);
Y2 = normalizeAudio(Y2);
Y3 = normalizeAudio(Y3);

% The analysis mixes up the order of the signals so we need to match them
% ourselves.
% The matrices outputted from the analysis functions are matched by finding
% the original signal in S that is closest to each of the outputted
% signals.
Y1 = matchMatrices(S, Y1, RowsToFind); 
Y2 = matchMatrices(S, Y2, RowsToFind);
Y3 = matchMatrices(S, Y3, RowsToFind);

plotMatrix(Y1, 4, RowsToAnalyze, 3, "fastICA result");
plotMatrix(Y3, 4, RowsToAnalyze, 4, "PCA result");

% Print out the results
for i = 1:RowsToFind
    d = calculateDifference(S(i,:), Y1(i,:));
    fprintf('The difference in signal #%i from fastICA: %f\n', i, d);
end
for i = 1:RowsToFind
    d = calculateDifference(S(i,:), Y2(i,:));
    fprintf('The difference in signal #%i from kICA: %f\n', i, d);
end
for i = 1:RowsToFind
    d = calculateDifference(S(i,:), Y3(i,:));
    fprintf('The difference in signal #%i from PCA: %f\n', i, d);
end


%==== functions to help with plotting, calculating the difference between
%vectors and matching the matrices =====

% Plots the individual rows of the given matrix using subplot()
%
% Parameters:
%   mat - the matrix
%   rowCount - the amount of rows in the subplot
%   colCount - the amount of rows to draw from the matrix, each to
%               different column of the subplot
%   row - the row of subplot to draw the rows of the matrix
%
function [] = plotMatrix(mat, rowCount, colCount, row, titl)
    [r, c] = size(mat);
    e = min([colCount, r]);
    for i = 1:e
        subplot(rowCount,colCount,(row-1) * colCount + i);
        plot(mat(i,:));
        title(strcat(titl, {' '}, num2str(i)));
    end
end


% Matches the rows in the second matrix with the rows of the first one
% by finding the ones that are closest to each other in terms of euclidean
% distance.
% If matrices row counts dont match, add all zero rows to mat2
%
% Parameters:
%   mat1 - first matrix, the one that will be sorted
%   mat2 - second matrix
%   rows - the amount of rows to sort, starting with 1
%
% Returns:
%   mat - sorted version of mat2
%
function [mat] = matchMatrices(mat1, mat2, rows)
    mat = mat2;
    [r, c] = size(mat);
    [r2, c2] = size(mat1);
    while r2 > r
        r = r + 1;
        mat(r, :) = zeros(1, c);
    end
    for i = rows:-1:1 % start from the end row => priorisize the first rows
        [index, inverse, row] = findClosest(mat1, mat(i, :)); % find the index of the closest row
        temp = mat(i, :); % swap the rows
        mat(i, :) = mat(index, :);
        mat(index, :) = temp;
        if inverse == 1 % if inverse then inverse the row
            mat(i, :) = mat(i, :) * -1;
        end
    end
end


% Finds the row of the given matrix that is closest to the given vector
% Also checks inversed versions of each rows (each sample *= -1)
%
% Parameters:
%   mat - The matrix
%   vec - The vector
%
% Returns:
%   index - The index of the row that is closest to the given vector
%   inverse - True if the row is inversed, False if not
%   row - the closest row in mat, inversed if closest that way
%
function [index, inverse, row] = findClosest(mat, vec)
    [r, c] = size(mat);
    if length(vec) ~= c
        error("Vector length and matrix column count do not match.");
    else        
        min = calculateDifference(mat(1,:), vec);
        inverse = 0;
        index = 1;
        row = mat(1,:);
        for i = 2:r
            dif = calculateDifference(mat(i,:), vec);
            if(dif < min)
               min = dif;
               index = i;
               row = mat(i, :);
            end
        end
        for i = 1:r
            dif = calculateDifference(mat(i,:), vec * -1);
            if(dif < min)
               min = dif;
               index = i;
               inverse = 1;
               row = mat(i, :) * -1;
            end
        end
    end
end


% Calculates the difference between two vectors.
% The diffenrece is the euclidean distance between the vectors.
% It is calculated with the formula Sqrt((a1 - b1)^2 + (a2 - b2)^2 + .... + (an - bn)^2)
%
% Parameters:
%   vec1 - first vector
%   vec2 - second vector
%
% Returns:
% diff - The difference between the vectors
%
function [diff] = calculateDifference(vec1, vec2)
    if length(vec1) ~= length(vec2)
        error("Vectors must have the same length.");
    else
        diff = 0;
        for i = 1:length(vec1)
            diff = diff + (vec1(i) - vec2(i))^2;
        end
        diff = sqrt(diff);
    end
end
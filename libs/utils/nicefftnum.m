function N = nicefftnum(n)
% NICEFFTNUM Choose an FFT-friendly even length >= n.
%
% Returns the smallest candidate N of the form N = t * 2^k with
% t in {1, 3, 5, 9, 15, 25, 27} and k >= 1 such that N >= n.
% Such N are 5-smooth (prime factors subset of {2,3,5}) and even.
% Mixed-radix Cooley–Tukey FFTs run fastest on these sizes; when N has
% large prime factors, libraries often fall back to slower algorithms
% (e.g., Rader/Bluestein) or inefficient large radices. Picking a nearby
% 5-smooth, even N avoids those slow paths and improves performance.
%
% Input:
%   n    - Desired minimum FFT length (scalar, n > 0).
% Output:
%   N    - Selected FFT length (scalar), with N >= n.
%
% Method:
%   For each t in {1,3,5,9,15,25,27}, compute the smallest power-of-two
%   multiplier 2^k (with k = max(1, ceil(log2(n/t)))) that makes t*2^k >= n.
%   Choose the minimum among those candidates. This heuristic does not search
%   all 5-smooth numbers, but typically yields a fast N close to n.
%
% Original: C. Wilson, 10-Oct-1999
% Coauthor: Rubem Pacelli
%   ORCID: https://orcid.org/0000-0001-5933-8565
% Updated: 2025-09-04T22:09:57Z

t = [1, 3, 5, 9, 15, 25, 27];
k = max(1, ceil(log2(n ./ t)));
candidate_lengths = 2.^k .* t;  % t * 2^k for each t
N = min(candidate_lengths);
end

function alpha = circ_vmrnd(theta, kappa, n)
%
% alpha = circ_vmrnd(theta, kappa, n)
%   Simulates n random angles from a von Mises distribution, with preferred 
%   direction theta and concentration parameter kappa.
%
%   Input:
%     [theta    preferred direction, default is 0]
%     [kappa    width, default is 1]
%     [n        number of samples, default is 10]
%
%     If n is a vector with multiple entries (e.g. [2 10]), the function creates
%     a matrix output with the respective dimensionality.
%
%   Output:
%     alpha     samples from von Mises distribution
%
%   References:
%     Statistical analysis of circular data, Fisher, sec. 3.3.6, p. 49
%
% Circular Statistics Toolbox for Matlab

% By Philipp Berens and Marc J. Velasco, 2009
% velasco@ccs.fau.edu


% default parameter
if nargin < 3
    n = 10;
end

if nargin < 2
    kappa = 1;
elseif ~(isscalar(kappa) && isnumeric(kappa) && isfinite(kappa) && kappa >= 0)
    error('CIRCSTAT:circ_vmrnd:inputType', 'Kappa must be a non-negative scalar');
end

if nargin < 1
    theta = 0;
elseif ~(isscalar(theta) && isnumeric(theta) && isfinite(theta))
    error('CIRCSTAT:circ_vmrnd:inputType', 'Theta must be a single numeric value');
end
    
n_points = prod(n);

% if kappa is small, treat as uniform distribution
if kappa < 1e-6
    alpha = 2*pi*rand(n_points, 1)-pi;
    return
end

% other cases
a = 1 + sqrt((1+4*kappa.^2));
b = (a - sqrt(2*a))/(2*kappa);
r = (1 + b^2)/(2*b);

alpha = zeros(n_points, 1);
for j = 1:n_points
  while true
      u = rand(3,1);

      z = cos(pi*u(1));
      f = (1+r*z)/(r+z);
      c = kappa*(r-f);

      if u(2) < c * (2-c) || ~(log(c)-log(u(2)) + 1 -c < 0)
         break
      end      
  end

  alpha(j) = theta +  sign(u(3) - 0.5) * acos(f);
end

alpha = angle(exp(1i .* alpha));

if ~isscalar(n)
  alpha = reshape(alpha, n);
end

end

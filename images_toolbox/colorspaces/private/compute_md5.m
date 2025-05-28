function chk_sum = compute_md5(input_bytes)
%COMPUTE_MD5 calculate MD5 checksum.
%   CHK_SUM = COMPUTE_MD5(INPUT_BYTES) computes the MD5 checksum on the
%   array INPUT_BYTES and returns it as a 16-element uint8 vector. 
%
%   Class Support
%   -------------
%   INPUT_BYTES and CHK_SUM are both nonsparse uint8 arrays.

%   Copyright 2008-2020 The MathWorks, Inc.

% validate input
validateattributes(input_bytes,{'uint8'},{'nonsparse'});

% generate uint8 checksum
if ~isempty(input_bytes)
     chk_sum = matlab.internal.crypto.BasicDigester("DeprecatedMD5").computeDigest(input_bytes(:));
else
    % Default value obtained using
%     import java.security.MessageDigest;
%     MessageDigest.getInstance('MD5').digest()
     chk_sum = typecast(int8([-44 29 -116 -39 -113 0 -78 4 -23 -128 9 -104 -20 -8 66 126]),'uint8');
end
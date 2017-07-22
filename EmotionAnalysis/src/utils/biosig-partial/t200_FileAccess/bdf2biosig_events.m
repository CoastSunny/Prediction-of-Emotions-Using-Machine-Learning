function HDR=bdf2biosig_events(HDR, Mode)
% BDF2BIOSIG_EVENTS converts BDF Status channel into BioSig Event codes. 
%
%  HDR = bdf2biosig_events(HDR [,Mode])   
%
% INPUT:
%   HDR is the header structure generated by SOPEN, SLOAD or mexSLOAD
%	from loading a Biosemi (BDF) file.
%	Specifically, HDR.BDF.ANNONS contains the info of the status channel. 
%   Mode [default = 4]
%	determines how the BDF status channel is converted into 
% 	the event table HDR.EVENT. Currently, the following modes are 
%	supported: 
%	 1: epoching information is derived from bit17
%	    only lower 8 bits are supported
%	 2: suggested decoding if standardized event codes (according to 
%	    .../biosig/doc/eventcodes.txt) are used  
%	 3: Trigger Input 1-15, raising and falling edges
%	 4: [default] Trigger Input 1-15, raising edges
%	 5: Trigger input 1-8, raising and falling edges are considered
%	 6: Trigger input 1-8, only raising edges are considered
%	 7: bit-based decoding 
%	99: not recommended, because it could break some functionality in BioSig 
% Output: 	
%   HDR.EVENT contains the generated Event table.  	
% 
% see also: doc/eventcodes.txt, doc/header.txt, SOPEN, SLOAD
% 
% 
% Referenzes: 
% [1] http://www.biosemi.com/faq/file_format.htm
% [2] http://www.biosemi.com/faq/trigger_signals.htm


%	$Id: bdf2biosig_events.m 2816 2011-11-07 07:04:27Z schloegl $
%	Copyright (C) 2007,2008,2009,2011 by Alois Schloegl <a.schloegl@ieee.org>	
%    	This is part of the BIOSIG-toolbox http://biosig.sf.net/

% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Library General Public
% License as published by the Free Software Foundation; either
% Version 2 of the License, or (at your option) any later version.
%
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% Library General Public License for more details.
%
% You should have received a copy of the GNU Library General Public
% License along with this library; if not, write to the
% Free Software Foundation, Inc., 59 Temple Place - Suite 330,
% Boston, MA  02111-1307, USA.


if nargin<2 || isempty(Mode),
	Mode = 4; 
end; 

if ~isfield(HDR,'BDF') || ~isfield(HDR.BDF,'ANNONS')
	%% is not a BDF file 
	return; 
end; 
t = HDR.BDF.ANNONS;

ix1 = diff(double([0;bitand(t,2^16)]));	% start of epoch
ix2 = diff(double([0;bitand(t,2^16-1)]));	% labels 

% defines mapping of the BDF-status channel to BioSig event codes 			
switch Mode,    % determines default decoding

case 1,	
	% epoching information is derived from bit17
	% only lower 8 bits are supported
	POS = [find(ix1>0);find(ix2>0);find(ix1<0);find(ix2<0)];
	TYP = [repmat(hex2dec('7ffe'),sum(ix1>0),1); bitand(t(ix2>0),255); repmat(hex2dec('fffe'),sum(ix1<0),1); bitor(bitand(t(find(ix2<0)-1),255),2^15)];
	
case 2, 
	% suggested decoding if standardized event codes (according to 
	% .../biosig/doc/eventcodes.txt) are used  
	POS = [find(ix2>0)];
	TYP = [bitand(t(ix2>0),2^16-1)];
	
case 3,
	% Trigger Input 1-15, raising and falling edges
	t = bitand(HDR.BDF.ANNONS,2^16-1);
	t(~~bitand(HDR.BDF.ANNONS,2^16)) = 0; 
	ix2 = diff(double([0;bitand(t,2^16-1)]));	% labels 
	POS = [find(ix2)];
 	TYP = [t(ix2>0); t(find(ix2<0)-1)+hex2dec('8000')];
		
case 4,
	% Trigger Input 1-15, raising edges
	t = bitand(HDR.BDF.ANNONS,2^16-1);
	t(~~bitand(HDR.BDF.ANNONS,2^16)) = 0; 
	ix2 = diff(double([0;bitand(t,2^16-1)]));	% labels 
	POS = [find(ix2>0)];
	TYP = [t(ix2>0)];
		
case 5,
	% Trigger input 1-8, raising and falling edges are considered
	t = bitand(HDR.BDF.ANNONS,255);			% only bit1-8 are considered, useful if bit9-16 are open/undefined
	t(~~bitand(HDR.BDF.ANNONS,2^16)) = 0; 
	ix2 = diff(double([0;bitand(t,2^16-1)]));	% labels 
	POS = [find(ix2)];
 	TYP = [t(ix2>0); t(find(ix2<0)-1)+hex2dec('8000')];
		
case 6,
	% Trigger input 1-8, only raising edges are considered
	t = bitand(HDR.BDF.ANNONS,255);			% only bit1-8 are considered, useful if bit9-16 are open/undefined
	t(~~bitand(HDR.BDF.ANNONS,2^16)) = 0; 
	ix2 = diff(double([0;bitand(t,2^16-1)]));	% labels 
	POS = [find(ix2>0)];
	TYP = [t(ix2>0)];
		
case 7,
	%% bit-based decoding 
	POS = [];
	TYP = [];
	for k=1:16,
		t = bitand(HDR.BDF.ANNONS,2^(k-1));
		t = t~=t(1);			% support of low-active and high-active
		ix2 = diff(double([0;t]));	% labels 
		POS = [POS; find(ix2>0); find(ix2<0)];
 		TYP = [TYP; repmat(k,sum(ix2>0),1); repmat(k+hex2dec('8000'),sum(ix2<0),1)];
 		HDR.EVENT.CodeDesc{k} = sprintf('bit %i',k);
	end;
case 8,
	%% bit-based decoding with only high-active 
	POS = [];
	TYP = [];
	for k=1:16,
		t = bitand(HDR.BDF.ANNONS,2^(k-1));
		ix2 = diff(double([0;t])); 
		POS = [POS; find(ix2>0)];
		TYP = [TYP; repmat(k,sum(ix2>0),1)];
		HDR.EVENT.CodeDesc{k} = sprintf('bit %i',k);
	end;
	
case 99,
	% not recommended, because it could break some functionality in BioSig 
	POS = [find(ix2>0);find(ix2<0)];
 	TYP = [bitand(t(ix2>0),2^16-1); bitor(bitand(t(find(ix2<0)-1),2^16-1),2^15)];

otherwise,
	fprintf(HDR.FILE.stderr,'Warning BDF2BIOSIG_EVENTS: Mode BDF:%d not supported\n', Mode);

end;
HDR.EVENT = [];
[HDR.EVENT.POS,ix] = sort(POS);
HDR.EVENT.TYP = TYP(ix);


%%%% BDF Trigger and status 
t = bitand(HDR.BDF.ANNONS,hex2dec('00ffff')); 
ix = diff(double([0;t]));
HDR.BDF.Trigger.POS = find(ix);
HDR.BDF.Trigger.TYP = t(HDR.BDF.Trigger.POS); 			

t = bitand(bitshift(HDR.BDF.ANNONS,-16),hex2dec('00ff')); 
ix = diff(double([0;t]));
HDR.BDF.Status.POS = find(ix);
HDR.BDF.Status.TYP = t(HDR.BDF.Status.POS); 			

%HDR.BDF.ANNONS = []; 	% not needed anymore, saves memory

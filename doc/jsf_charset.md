

#Module jsf_charset#
* [Function Index](#index)
* [Function Details](#functions)




<a name="index"></a>

##Function Index##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#classify-1">classify/1</a></td><td>looks at the In and tries to classify the string as either
'ascii' (7bit), 'jis' (7bit) or 'utf8' or '8bit'.</td></tr><tr><td valign="top"><a href="#classify2-1">classify2/1</a></td><td>classify2 runs through a binary byte-by-byte and tries to classify
if as either '7bit','8bit','iso-2022' or 'utf8'.</td></tr><tr><td valign="top"><a href="#classify2-2">classify2/2</a></td><td></td></tr><tr><td valign="top"><a href="#force_to_utf8-1">force_to_utf8/1</a></td><td></td></tr><tr><td valign="top"><a href="#valid8-1">valid8/1</a></td><td>Checks if the Input starts with a valid utf8 character.</td></tr></table>


<a name="functions"></a>

##Function Details##

<a name="classify-1"></a>

###classify/1##




<pre>classify(In::binary()) -&gt; ascii | jis | utf8 | '8bit'</pre>
<br></br>




looks at the In and tries to classify the string as either
'ascii' (7bit), 'jis' (7bit) or 'utf8' or '8bit'. Classification is
strict and fails quickly to 8bit if an 8bit byte is found. @see
classify2/2 for a less strict classifier.<a name="classify2-1"></a>

###classify2/1##




<pre>classify2(In::binary()) -&gt; {'7bit' | '8bit' | 'iso-2022' | utf8, non_neg_integer()}</pre>
<br></br>




classify2 runs through a binary byte-by-byte and tries to classify
if as either '7bit','8bit','iso-2022' or 'utf8'. For big data a max number
of bytes can be specified to reduce the overhead. Classification allows
for a certain amount of misc-bytes in the data so for example a bad byte
in what is otherwise perfect utf-8 will still be classified as utf8.<a name="classify2-2"></a>

###classify2/2##




<pre>classify2(In::binary(), Max::pos_integer() | undefined) -&gt; {'7bit' | '8bit' | 'iso-2022' | utf8, non_neg_integer()}</pre>
<br></br>


<a name="force_to_utf8-1"></a>

###force_to_utf8/1##




<pre>force_to_utf8(In::binary()) -&gt; binary()</pre>
<br></br>


<a name="valid8-1"></a>

###valid8/1##




<pre>valid8(In::binary()) -&gt; {true, binary()} | false | fuzzy</pre>
<br></br>




Checks if the Input starts with a valid utf8 character. If it is
utf8 it returns true and a binary starting from the next byte following
that utf8 character. If it is not utf8, then it returns false. If the
stream ends with a truncated potential utf-8, it returns 'fuzzy' as its
not certain if it would be a utf-8 character if we had more data or not.
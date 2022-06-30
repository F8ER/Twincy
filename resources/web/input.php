<?php
	function post(&$data, &$type, &$size)
	{
		$type = null;

		if ($_SERVER['REQUEST_METHOD'] !== 'POST')
		{
			return false;
		}

		$size = (int)($_SERVER['CONTENT_LENGTH']);

		if ($_SERVER["CONTENT_TYPE"] === 'application/x-www-form-urlencoded' || $_SERVER["CONTENT_TYPE"] === 'multipart/form-data')
		{
			$data = $_POST;
			$type = 1;

			return true;
		}

		$data = file_get_contents('php://input');
		$type = 2;

		return true;
	}

	function jsonEncode($source, &$result, $fallback = null, $flags = JSON_FORCE_OBJECT)
	{
		$result = json_encode($source, $flags);

		if (json_last_error() !== JSON_ERROR_NONE)
		{
			$result = $fallback;

			return false;
		}
		
		return true;
	}

	function jsonDecode($source, &$result, $fallback = null, $assoc = true)
	{
		$result = json_decode($source, $assoc);
		
		if (json_last_error() !== JSON_ERROR_NONE)
		{
			$result = $fallback;

			return false;
		}
		
		return true;
	}

	// Random string function
	function randString( $length = 8, $charSetCustom = null )
	{
		if ( $charSetCustom !== null )
		{
			$charSet = $charSetCustom;
		}
		else
		{
			$charSet = '1234567890';
		}

		$charSetLength = strlen( $charSet );
		$resultString = '';

		for ($charIndex = 0; $charIndex < $length; $charIndex++)
		{ 
			$resultString .= $charSet[ rand(0, $charSetLength - 1) ];
		}

		return $resultString;
	}

	function pskVerify($data)
	{
		if (empty($data['psk']) || strlen($data['psk']) < 8 || strlen($data['psk']) > 64)
		{
			// header('Location: /index.php?r=3#' . randString( 32 ));
			echo json_encode(['status' => -1]);
			die;
		}

		$pskTry = $data['psk'];
		$verifyTimeout = 20000; // ms

		// ---
		// Main
		// ---

		$pskTryFilenamePrefix = 'psk-try';
		$pskCheckedFilenamePrefix = 'checked';

		$ipEscaped = preg_replace('/\./', '-', $_SERVER['REMOTE_ADDR']);

		// Where the Twincy check result is stored
		$pskUncheckedFilename = $pskTryFilenamePrefix . '_' . $ipEscaped . '_' . randString(8) . '_' . time();
		$pskCheckResultFilename = $pskCheckedFilenamePrefix . '_' . $pskUncheckedFilename;

		// Dirpaths
		$pskUncheckedDirpath = ROOT_DIR . '/psk_tries';

		// Filepaths
		$pskUncheckedFilepath = $pskUncheckedDirpath . '/' . $pskUncheckedFilename;
		$pskCheckResultFilepath = $pskUncheckedDirpath . '/' . $pskCheckResultFilename;

		// Write down the PSK try to the file
		$pskUnchecked = fopen($pskUncheckedFilepath, 'a');
		fwrite($pskUnchecked, $pskTry . "\n");
		fclose($pskUnchecked);
		$verifyStartTime = floor(microtime(true) * 1000);

		// While "unchecked" or "check result" file exists
		// (Wait till Twincy checks if the PSK is correct)
		// (Twincy removes "pskUncheckedFilepath", the web backend - "pskCheckResultFilepath")
		// (The first file is required for waiting until Twincy's process the request) and prevents an infinite loop if Twincy didn't check the PSK and terminated.
		// So the file's removal or a session clear would stop it)
		// // (The second file prevents a loop end, if Twincy already removed "pskUncheckedFilepath", but web backend haven't check the result, yet
		// An issue: if someone sent a correct PSK and then incorrect, after Twincy's PSK tries check loop, that user may see an error message because
		// the user's PHP request session would change and they'll wait for a different(next) "pskCheckResultFilepath" file.
		// Managing that perhaps is impossible except IP addresses (i.e. IP request limit) - (would this work correctly on LAN?)
		while(file_exists($pskUncheckedFilepath) || ! file_exists($pskCheckResultFilepath))
		{
			# If verification timeout occured
			if ($verifyStartTime + $verifyTimeout < floor(microtime(true) * 1000))
			{
				echo json_encode(['status' => 3]);

				die;
			}

			sleep(1);
		}

		$pskCheckedResultTrimmed = trim(file_get_contents($pskCheckResultFilepath));

		// If PSK is incorrect
		if ( $pskCheckedResultTrimmed === '0' )
		{
			echo json_encode(['status' => 2]);
			// header('Location: /index.php?r=2#' . randString( 32 ));

			// Move the result file and tell Twincy that web client read the result
			// rename($pskCheckResultFilepath, $pskCheckResultFilepath . "_notified");
			unlink($pskCheckResultFilepath);
			die;
		}

		// If PSK is correct
		if ( $pskCheckedResultTrimmed === '1' )
		{
			echo json_encode(['status' => 1]);
			// header('Location: /index.php?r=1#' . randString( 32 ));

			// Move the result file and tell Twincy that web client read the result
			// rename($pskCheckResultFilepath, $pskCheckResultFilepath . "_notified");
			unlink($pskCheckResultFilepath);
			die;
		}
	}

	if (post($postDataRaw, $postType, $postSize) && jsonDecode($postDataRaw, $postData))
	{
		try
		{
			pskVerify($postData);
		}
		catch (Exception $exception)
		{
			error_log($exception);
		}
	}
?>
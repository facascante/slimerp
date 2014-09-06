<?php 

use models\Realms;

$app->get('/v01/realms', function () use ($app) {	
	
	$object = new Realms();
	$list = $object->getRealms();
	$app->contentType('application/json');
	echo json_encode($list);
});
$app->get('/v01/realms/01', function () use ($app) {
	
		$app->render('ace.html');
});

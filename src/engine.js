var cameraPosition = [30, 30, 30]

//生成的纹理的分辨率，纹理必须是标准的尺寸 256*256 1024*1024  2048*2048
var resolution = 2048;
var fbo;

GAMES202Main();

function GAMES202Main() {
	// Init canvas and gl
	const canvas = document.querySelector('#glcanvas');
	canvas.width = window.screen.width;
	canvas.height = window.screen.height;
	const gl = canvas.getContext('webgl');
	if (!gl) {
		alert('Unable to initialize WebGL. Your browser or machine may not support it.');
		return;
	}

	// Add camera
	const camera = new THREE.PerspectiveCamera(75, gl.canvas.clientWidth / gl.canvas.clientHeight, 1e-2, 1000);
	camera.position.set(cameraPosition[0], cameraPosition[1], cameraPosition[2]);

	// Add resize listener
	function setSize(width, height) {
		camera.aspect = width / height;
		camera.updateProjectionMatrix();
	}
	setSize(canvas.clientWidth, canvas.clientHeight);
	window.addEventListener('resize', () => setSize(canvas.clientWidth, canvas.clientHeight));

	// Add camera control
	const cameraControls = new THREE.OrbitControls(camera, canvas);
	cameraControls.enableZoom = true;
	cameraControls.enableRotate = true;
	cameraControls.enablePan = true;
	cameraControls.rotateSpeed = 0.3;
	cameraControls.zoomSpeed = 1.0;
	cameraControls.panSpeed = 0.8;
	cameraControls.target.set(0, 0, 0);

	// Add renderer
	const renderer = new WebGLRenderer(gl, camera);

	// Add lights
	// light - is open shadow map == true
	let lightPos = [0, 80, 80];
	let focalPoint = [0, 0, 0]; // 定向平行光聚焦末坐标(起点是lightPos)
	let lightUp = [0, 1, 0]


	const directionLight = new DirectionalLight(5000, [1, 1, 1], lightPos, focalPoint, lightUp, true, renderer.gl);
	renderer.addLight(directionLight);

	// Add shapes
	
	let floorTransform = setTransform(0, 0, -30, 4, 4, 4);
	let obj1Transform = setTransform(0, 0, 0, 20, 20, 20);
	let obj2Transform = setTransform(40, 0, -40, 10, 10, 10);

	// loadOBJ(renderer, path, name, objMaterial, transform, meshID);
	loadOBJ(renderer, 'assets/mary/', 'Marry', 'PhongMaterial', obj1Transform, "1");
	loadOBJ(renderer, 'assets/mary/', 'Marry', 'PhongMaterial', obj2Transform, "2");
	loadOBJ(renderer, 'assets/floor/', 'floor', 'PhongMaterial', floorTransform, "3");

	const ObjGUI = {
		Moveable: false,
		Pos1: obj1Transform,
		Pos2: obj2Transform
	};

	// let floorTransform = setTransform(0, 0, 0, 100, 100, 100);
	// let cubeTransform = setTransform(0, 50, 0, 10, 20, 10);
	// let sphereTransform = setTransform(30, 10, 0, 10, 10, 10);

	// loadOBJ(renderer, 'assets/testObj/', 'testObj', 'PhongMaterial', cubeTransform);
	// loadOBJ(renderer, 'assets/basic/', 'sphere', 'PhongMaterial', sphereTransform);
	// loadOBJ(renderer, 'assets/basic/', 'plane', 'PhongMaterial', floorTransform);

	obj1Transform

	function createGUI() {
		const gui = new dat.gui.GUI();
		const panelModel = gui.addFolder('Object properties');

		const lightMoveableController = panelModel.add(ObjGUI, 'Moveable').name("OBJ_Moveable");

		const Object1Folder = panelModel.addFolder('Object1 Pos');
		const Object2Folder = panelModel.addFolder('Object2 Pos');

		Object1Folder.add(ObjGUI.Pos1, 'modelTransX').min(-20).max( 20).step(1).name("Obj1 Pos X");
		Object1Folder.add(ObjGUI.Pos1, 'modelTransY').min(-20).max( 20).step(1).name("Obj1 Pos Y");
		Object1Folder.add(ObjGUI.Pos1, 'modelTransZ').min(-20).max( 20).step(1).name("Obj1 Pos Z");

		Object2Folder.add(ObjGUI.Pos2, 'modelTransX').min( 20).max( 80).step(1).name("Obj2 Pos X");
		Object2Folder.add(ObjGUI.Pos2, 'modelTransY').min(-20).max( 20).step(1).name("Obj2 Pos Y");
		Object2Folder.add(ObjGUI.Pos2, 'modelTransZ').min(-80).max(-20).step(1).name("Obj2 Pos Z");
		
		Object1Folder.domElement.style.display = ObjGUI.Moveable ? '' : 'none';
		Object2Folder.domElement.style.display = ObjGUI.Moveable ? '' : 'none';
		lightMoveableController.onChange(function(value) {
			Object1Folder.domElement.style.display = value ? '' : 'none';
			Object2Folder.domElement.style.display = value ? '' : 'none';
		});
	}
	createGUI();

	function mainLoop() {
		cameraControls.update();
		renderer.render();
		requestAnimationFrame(mainLoop);

		if(ObjGUI.Moveable){
			renderer.setTranslateScale('1',
				[ObjGUI.Pos1.modelTransX, ObjGUI.Pos1.modelTransY, ObjGUI.Pos1.modelTransZ],
				[ObjGUI.Pos1.modelScaleX, ObjGUI.Pos1.modelScaleY, ObjGUI.Pos1.modelScaleZ]);
			renderer.setTranslateScale('2',
				[ObjGUI.Pos2.modelTransX, ObjGUI.Pos2.modelTransY, ObjGUI.Pos2.modelTransZ],
				[ObjGUI.Pos2.modelScaleX, ObjGUI.Pos2.modelScaleY, ObjGUI.Pos2.modelScaleZ]);
		}
	}
	requestAnimationFrame(mainLoop);
}

function setTransform(t_x, t_y, t_z, s_x, s_y, s_z) {
	return {
		modelTransX: t_x,
		modelTransY: t_y,
		modelTransZ: t_z,
		modelScaleX: s_x,
		modelScaleY: s_y,
		modelScaleZ: s_z,
	};
}

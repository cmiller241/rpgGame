class Map {
    constructor(width,height,mapFileName) {
        this.width = width;
        this.height = height;
        this.mapFileName = mapFileName;
        this.mapArray = null;
    }

    load() {
 

        const existingScript = document.getElementById('mapScript');
        if (existingScript) {
            document.head.removeChild(existingScript);
        }

        const script = document.createElement('script');
        script.src = `/${this.mapFileName}`;
        script.id = 'mapScript';
        script.onload = () => {
            const mapArray = window.mapArray;
            if (mapArray) {
                this.mapArray = mapArray;
            }
        }
        document.head.appendChild(script);    
    }
}
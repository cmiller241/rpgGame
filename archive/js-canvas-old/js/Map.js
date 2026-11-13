class Map {
    constructor(width,height,mapFileName) {
        this.width = width;
        this.height = height;
        this.mapFileName = mapFileName;
        this.mapArray = null;
    }

    async load() {
        try {
            await this.loadMapScript();
            const mapArray = window.mapArray;
            if (mapArray) {
                this.mapArray = mapArray;
                console.log("THe map array is loaded");
            } else {
                console.log("The map array is null");
            }
            return Promise.resolve();
        } catch {
            console.error("Error loading map:", error);
            return Promise.reject(error);
        }
    }

    loadMapScript() {
        return new Promise((resolve, reject) => {
            const existingScript = document.getElementById('mapScript');
            if (existingScript) {
                document.head.removeChild(existingScript);
            }
            const script = document.createElement('script');
            script.src = `/${this.mapFileName}`;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }
}
let app = angular.module('featuresApp', []);

app.controller('ItemsCtrl', function ($scope, $http) {
    $scope.items = [];
    $scope.currentPage = 1;
    $scope.totalPages = 1;
    $scope.perPage = 5;
    $scope.magType = 'all';
    $scope.error = null

    function fetchData(page, per_page, mag_type) {
        $http.get('/api/features', {params: {page: page, per_page: per_page, mag_type: mag_type}})
            .then(function (response) {
                $scope.items = response.data.data;
                $scope.totalPages = response.data.pagination.total;
                console.log($scope.items);
                if ($scope.items.length === 0) {
                    $scope.currentPage = 1;
                    $scope.totalPages = 1;
                    $scope.perPage = 5;
                    $scope.error = "Error there is no data with that magnitude type. Try another";
                    // fetchData($scope.currentPage, $scope.perPage);
                }else
                {
                    $scope.error = null
                }

            })
            .catch(function (error) {
                console.error(error);
                $scope.error = `Error: ${error.message}`;

            });
    }

    fetchData($scope.currentPage, $scope.perPage);

    $scope.filterByMagType = function () {
        $scope.currentPage = 1;
        $scope.totalPages = 1;
        $scope.perPage = 5;
        fetchData($scope.currentPage, $scope.perPage, $scope.magType);
    };

    $scope.nextPage = function () {
        if ($scope.currentPage < $scope.totalPages) {
            $scope.currentPage++;
            fetchData($scope.currentPage, $scope.perPage, $scope.magType);
        }
    };

    $scope.prevPage = function () {
        if ($scope.currentPage > 1) {
            $scope.currentPage--;
            fetchData($scope.currentPage, $scope.perPage,$scope.magType);
        }
    };
});
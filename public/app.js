let app = angular.module('myApp', []);

app.controller('ItemsCtrl', function($scope, $http) {
  $scope.items = [];
  $scope.currentPage = 1;
  $scope.totalPages = 1;
  $scope.perPage = 10;

  function fetchData(page,per_page) {
    $http.get('/api/features', { params: { page: page ,per_page: per_page} })
      .then(function(response) {
        $scope.items = response.data.data;
        $scope.totalPages = Math.ceil(response.data.pagination.total / per_page);
      })
      .catch(function(error) {
        console.error(error);
      });
  }

  fetchData($scope.currentPage,$scope.perPage);

  $scope.nextPage = function() {
    if ($scope.currentPage < $scope.totalPages) {
      $scope.currentPage++;
      fetchData($scope.currentPage,$scope.perPage);
    }
  };

  $scope.prevPage = function() {
    if ($scope.currentPage > 1) {
      $scope.currentPage--;
      fetchData($scope.currentPage,$scope.perPage);
    }
  };
});
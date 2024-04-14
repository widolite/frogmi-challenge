let app = angular.module('commentApp', []);

app.controller('CommentCtrl', function ($scope, $http) {
    $scope.comment = '';
    $scope.featureId = 0;
    $scope.result = null;
    $scope.error = null;
    $scope.data = {};

    $scope.submitComment = function () {
        let feature_id = $scope.featureId;
        $http.post(`/api/features/${feature_id}/comments`, $scope.data)
            .then(response => {
                $scope.result = response.data.message;
                $scope.data.body = "";
                $scope.featureId = feature_id;
                $scope.error = null;
            })
            .catch(error => {
                $scope.result = null;
                $scope.error = "Error submitting comment. Please try again.";
                console.error(`status: ${error.data.status} - ${error.data.message}`);
            });
    };
});